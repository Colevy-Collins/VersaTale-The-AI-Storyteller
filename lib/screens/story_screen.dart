// lib/screens/story_screen.dart
import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';

import '../constants/story_tokens.dart';      // kPreviousLegToken
import '../services/auth_service.dart';
import '../services/story_service.dart';
import '../services/lobby_rtdb_service.dart';
import '../utils/lobby_utils.dart';
import '../utils/ui_utils.dart';
import '../models/story_phase.dart';
import '../widgets/action_button.dart';
import '../widgets/story_text_area.dart';
import '../widgets/next_action_sheet.dart';
import '../widgets/full_story_dialog.dart';
import 'main_splash_screen.dart';
import 'multiplayer_host_lobby_screen.dart';
import 'dashboard_screen.dart';

enum _MenuOption {
  backToScreen,
  startGroupStory,
  viewFullStory,
  saveStory,
  logout,
  closeMenu,
}

class StoryScreen extends StatefulWidget {
  final String initialLeg;
  final List<String> options;
  final String storyTitle;
  final String? sessionId; // null = solo, non‑null = multiplayer
  final String? joinCode;

  const StoryScreen({
    Key? key,
    required this.initialLeg,
    required this.options,
    required this.storyTitle,
    this.sessionId,
    this.joinCode,
  }) : super(key: key);

  @override
  _StoryScreenState createState() => _StoryScreenState();
}

class _StoryScreenState extends State<StoryScreen> {
  final AuthService       _authSvc  = AuthService();
  final StoryService      _storySvc = StoryService();
  final LobbyRtdbService  _lobbySvc = LobbyRtdbService();
  final LobbyUtils       _lobbyUtil = LobbyUtils();
  late final String _currentUid;

  final TextEditingController _textCtrl   = TextEditingController();
  final ScrollController      _scrollCtrl = ScrollController();
  StreamSubscription<DatabaseEvent>? _lobbySub;

  late List<String> _currentOptions;
  String _storyTitle = 'Interactive Story';
  StoryPhase _phase  = StoryPhase.story;
  bool   _busy       = false;
  Map<String,dynamic> _players = {};

  int _inLobbyCount = 0;
  bool   _loading  = false;
  bool get _isMultiplayer => widget.sessionId != null;
  bool get _isHost {
    final slot1 = _players['1'];
    return slot1 is Map && slot1['userId'] == FirebaseAuth.instance.currentUser?.uid;
  }

  @override
  void initState() {
    super.initState();
    _currentUid = FirebaseAuth.instance.currentUser?.uid ?? '';
    _textCtrl.text  = widget.initialLeg;
    _currentOptions = widget.options;
    _storyTitle     = widget.storyTitle;

    if (_isMultiplayer) {
      _lobbySub = _lobbySvc
          .lobbyStream(widget.sessionId!)
          .listen(_onLobbyUpdate);
    }
  }

  @override
  void dispose() {
    _lobbySub?.cancel();
    _textCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  void _showError(String msg) => context.showMessage(msg, isError: true);
  void _showSnack(String msg) => context.showMessage(msg, isError: false);

  void _closeAnyOptionSheet() {
    while (ModalRoute.of(context)?.isCurrent == false) {
      Navigator.of(context, rootNavigator: true).pop();
    }
  }

  void _onLobbyUpdate(DatabaseEvent event) {
    final root = (event.snapshot.value as Map?)?.cast<dynamic,dynamic>() ?? {};

    // ─── lobby count ───
    final newCount = root['inLobbyCount'] as int? ?? 0;
    if (newCount != _inLobbyCount) {
      setState(() => _inLobbyCount = newCount);
    }

    // 1️⃣ players
    _players = LobbyUtils.normalizePlayers(root['players']);

    // 2️⃣ phase change
    final newPhase = StoryPhaseParsing.fromString(
        root['phase']?.toString() ?? '');
    final phaseChanged = newPhase != _phase;

    // → only close when we've moved into vote‑results
    if (phaseChanged && newPhase == StoryPhase.results) {
      _closeAnyOptionSheet();
    }

    if (phaseChanged) setState(() => _phase = newPhase);

    // 3️⃣ host auto‑resolve
    if (_phase == StoryPhase.vote && _isHost && !_busy) {
      final voteCount   = LobbyUtils.normalizePlayers(root['storyVotes']).length;
      final playerCount = _players.length;
      if (playerCount > 0 && voteCount >= playerCount) {
        _resolveAndAdvance();
      }
    }

    // 4️⃣ payload update
    if (_phase == StoryPhase.story && root['storyPayload'] != null) {
      final p = (root['storyPayload'] as Map).cast<String,dynamic>();
      setState(() {
        _textCtrl.text   = p['initialLeg'] as String;
        _currentOptions  = List<String>.from(p['options'] as List);
        _storyTitle      = p['storyTitle'] as String;
      });
      _scrollCtrl.jumpTo(0);
    }

    // — DETECT A KICK: if my UID is no longer present
    final stillHere = _players.values.any((p) => p['userId'] == _currentUid);
    if (!stillHere) {
      // stop listening
      _lobbySub!.cancel();
      // send me back to Dashboard
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => HomeScreen()),
        );
      }
      return;
    }
  }
  Future<void> _rollbackToStoryPhase() async {
    if (mounted) setState(() => _phase = StoryPhase.story);
    if (_isMultiplayer) {
      try {
        await _lobbySvc.updatePhase(
          sessionId: widget.sessionId!,
          phase: StoryPhase.story.asString,
        );
      } catch (_) {}
    }
  }

  Future<void> _maybeAutoResolve() async {
    if (!_isHost || widget.sessionId == null) return;
    final ref  = FirebaseDatabase.instance.ref('lobbies/${widget.sessionId}');
    final snap = await ref.get();
    final raw  = snap.value;
    if (raw is! Map) return;

    final players = LobbyUtils.normalizePlayers(raw['players']);
    final votes   = LobbyUtils.normalizePlayers(raw['storyVotes']);
    final phaseEnum = StoryPhaseParsing.fromString(
        raw['phase']?.toString() ?? '');

    if (phaseEnum == StoryPhase.vote &&
        players.isNotEmpty &&
        votes.length >= players.length) {
      await _resolveAndAdvance();
    }
  }



  Future<void> _hostBringEveryoneBack() async {
    if (!_isHost || widget.sessionId == null) return;
    setState(() => _busy = true);

    try {
      // 2 flip back to story phase
      await _lobbySvc.updatePhase(
        sessionId: widget.sessionId!,
        phase: StoryPhase.story.asString,
      );
    } catch (e) {
      _showError('Error bringing everyone back: $e');
    } finally {
      setState(() => _busy = false);
    }
  }


  Future<void> _soloPreviousLeg() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final r = await _storySvc.getPreviousLeg();
      _textCtrl.text  = r['storyLeg'] ?? 'No leg returned.';
      _currentOptions = List<String>.from(r['options'] ?? []);
      if (r.containsKey('storyTitle')) _storyTitle = r['storyTitle'];
    } catch (e) {
      _showError('$e');
    } finally {
      setState(() => _busy = false);
      _scrollCtrl.jumpTo(0);
    }
  }

  Future<void> _submitVote(String choice) async {
    setState(() => _busy = true);
    try {
      await _lobbySvc.submitStoryVote(
        sessionId: widget.sessionId!,
        vote     : choice,
      );
      await _maybeAutoResolve();
    } catch (e) {
      _showError('$e');
      await _rollbackToStoryPhase();
    } finally {
      setState(() => _busy = false);
    }
  }

  Future<void> _resolveAndAdvance() async {
    _closeAnyOptionSheet();
    print(1);
    setState(() => _busy = true);
    try {
      await _lobbySvc.updatePhase(
        sessionId: widget.sessionId!,
        phase: StoryPhase.results.asString,
      );
      print(2);
      final winner = await _lobbySvc.resolveStoryVotes(widget.sessionId!);
      print('Winner: $winner');
      if (winner == kPreviousLegToken) {
        final prev = await _storySvc.getPreviousLeg();
        await _lobbySvc.advanceToStoryPhase(
          sessionId: widget.sessionId!,
          storyPayload: {
            'initialLeg': prev['storyLeg'],
            'options'   : List<String>.from(prev['options'] ?? []),
            'storyTitle': prev['storyTitle'],
          },
        );
      } else {
        final next = await _storySvc.getNextLeg(decision: winner);
        await _lobbySvc.advanceToStoryPhase(
          sessionId: widget.sessionId!,
          storyPayload: {
            'initialLeg': next['storyLeg'],
            'options'   : List<String>.from(next['options'] ?? []),
            'storyTitle': next['storyTitle'],
          },
        );
      }
    } catch (e) {
      _showError('Error resolving votes: $e');
      await _rollbackToStoryPhase();
    } finally {
      setState(() => _busy = false);
    }
  }

  Future<void> _onNextSelected(String decision) async {
    // 1) first tap in multiplayer → open vote phase + submit
    if (_isMultiplayer && _phase == StoryPhase.story) {
      setState(() => _busy = true);
      try {
        await _lobbySvc.updatePhase(
          sessionId: widget.sessionId!,
          phase    : StoryPhase.vote.asString,
        );
        await _submitVote(decision);
      } catch (e) {
        _showError('$e');
        await _rollbackToStoryPhase();
      } finally {
        setState(() => _busy = false);
      }
      return;
    }

    // 2) already voting → change vote
    if (_isMultiplayer && _phase == StoryPhase.vote) {
      await _submitVote(decision);
      return;
    }
    print('Decision: $decision');
    // 3) solo → advance immediately
    setState(() => _busy = true);
    try {
      final resp = (decision == kPreviousLegToken)
          ? await _storySvc.getPreviousLeg()
          : await _storySvc.getNextLeg(decision: decision);
      _textCtrl.text  = resp['storyLeg'] ?? 'No leg returned.';
      _currentOptions = List<String>.from(resp['options'] ?? []);
      if (resp.containsKey('storyTitle')) _storyTitle = resp['storyTitle'];
    } catch (e) {
      _showError('$e');
    } finally {
      setState(() => _busy = false);
      _scrollCtrl.jumpTo(0);
    }
  }

  Future<void> _confirmAndGoBack() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('Warning', style: GoogleFonts.atma()),
        content: Text(
          'If you go back and then choose the same option, '
              'the next leg may differ. Continue?',
          style: GoogleFonts.atma(),
        ),
        actions: [
          TextButton(
            child: Text('Cancel', style: GoogleFonts.atma()),
            onPressed: () => Navigator.pop(context, false),
          ),
          TextButton(
            child: Text('Continue', style: GoogleFonts.atma()),
            onPressed: () => Navigator.pop(context, true),
          ),
        ],
      ),
    );
    if (ok != true) return;
    if (_isMultiplayer) {
      await _onNextSelected(kPreviousLegToken);
    } else {
      await _soloPreviousLeg();
    }
  }

  void _showFullStory() async {
    try {
      final r = await _storySvc.getFullStory(
        sessionId: _isMultiplayer && !_isHost ? widget.sessionId : null,
      );
      final txt = r['initialLeg'] ?? 'Story will appear here.';
      final ops = List<String>.from(r['options'] ?? []);
      final canPick = !_busy
         && (_phase == StoryPhase.story || _phase == StoryPhase.vote);
      showDialog(
        context: context,
        builder: (_) => FullStoryDialog(
          fullStory       : txt,
          dialogOptions   : ops,
          canPick         : canPick,
          onOptionSelected: (opt) {
            Navigator.pop(context);
            _onNextSelected(opt);
          },
          onShowOptions: () {
            Navigator.pop(context);
            _showOptionSheet(context);
          },
        ),
      );
    } catch (e) {
      _showSnack('$e');
    }
  }

  void _saveStory() async {
    try {
      final r = await _storySvc.saveStory(
        sessionId: _isMultiplayer && !_isHost ? widget.sessionId : null,
      );
      _showSnack(r['message'] ?? 'Story saved.');
    } catch (e) {
      _showSnack('$e');
    }
  }

  /// In whatever class you had before (e.g. in StoryScreen or a controller):
  Future<void> _createGroupSession() async {
    setState(() => _loading = true);
    try {
      if (!_isMultiplayer) {
        // 1) Get a fresh sessionId & joinCode from your backend
        final backendRes = await _storySvc.createMultiplayerSession("false");
        final newSessionId = backendRes['sessionId'] as String;
        final newJoinCode  = backendRes['joinCode']  as String;

        // 2) Seed RTDB lobby
        final hostName = FirebaseAuth.instance.currentUser?.displayName ?? 'Host';
        await _lobbySvc.createSession(
          sessionId:      newSessionId,
          hostName:       hostName,
          randomDefaults: {},
        );

        // 3) Broadcast the current solo story into RTDB
        await _lobbySvc.advanceToStoryPhase(
          sessionId: newSessionId,
          storyPayload: {
            'initialLeg': widget.initialLeg,
            'options':    widget.options,
            'storyTitle': widget.storyTitle,
          },
        );

        // 4) Build minimal playersMap (host only)
        final currentUid = FirebaseAuth.instance.currentUser?.uid ?? '';
        final playersMap = <int, Map<String, dynamic>>{
          1: {'displayName': hostName, 'userId': currentUid},
        };

        // 5) Flip the phase to 'lobby' using the NEW sessionId
        await _lobbySvc.updatePhase(
          sessionId: newSessionId,
          phase:     StoryPhase.lobby.asString,
        );

        // 6) Navigate into the host lobby screen
        if (!mounted) return;
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => MultiplayerHostLobbyScreen(
              sessionId:      newSessionId,
              joinCode:       newJoinCode,
              playersMap:     playersMap,
              fromSoloStory:  true,
              fromGroupStory: false,
            ),
          ),
        );

      } else {
        // ── already in multiplayer ──
        final existingSession = widget.sessionId!;
        final existingCode    = widget.joinCode!;

        final playersMap = await _lobbySvc.fetchPlayerList(
          sessionId: existingSession,
        );

        await _lobbySvc.updatePhase(
          sessionId: existingSession,
          phase:     StoryPhase.lobby.asString,
        );

        if (!mounted) return;
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => MultiplayerHostLobbyScreen(
              sessionId:      existingSession,
              joinCode:       existingCode,
              playersMap:     playersMap,
              fromSoloStory:  false,
              fromGroupStory: true,
            ),
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error creating session: $e')),
      );
    } finally {
      setState(() => _loading = false);
    }
  }

  void _showOptionSheet(BuildContext ctx) {
    final canPick = !_busy
        && (_phase == StoryPhase.story || _phase == StoryPhase.vote)
        && _inLobbyCount == 0;
    if (!canPick) return;

    showModalBottomSheet(
      context: ctx,
      builder: (_) => NextActionSheet(
        options: _currentOptions,
        busy: _busy,
        onPrevious: _confirmAndGoBack,
        onSelect: _onNextSelected,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // when the “Choose Next Action” button is enabled
    final canPick = !_busy
        && (_phase == StoryPhase.story || _phase == StoryPhase.vote)
        && _inLobbyCount == 0;

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        backgroundColor: Colors.white.withOpacity(0.7),
        elevation: 8,
        centerTitle: true,
        title: FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            _storyTitle,
            style: GoogleFonts.atma(
              fontWeight: FontWeight.bold,
              color: Colors.black,
            ),
          ),
        ),
        actions: [
          PopupMenuButton<_MenuOption>(
            icon: const Icon(Icons.menu, color: Colors.black),
            onSelected: (m) async {
              switch (m) {
                case _MenuOption.backToScreen:
                  Navigator.pop(context);
                  break;
                case _MenuOption.startGroupStory:
                  await _createGroupSession();
                  break;
                case _MenuOption.viewFullStory:
                  _showFullStory();
                  break;
                case _MenuOption.saveStory:
                  _saveStory();
                  break;
                case _MenuOption.logout:
                  await _authSvc.signOut();
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(builder: (_) => MainSplashScreen()),
                  );
                  break;
                case _MenuOption.closeMenu:
                  break;
              }
            },
            itemBuilder: (_) => const [
              PopupMenuItem(
                  value: _MenuOption.backToScreen,
                  child: Text('Back a Screen')),
              PopupMenuItem(
                  value: _MenuOption.startGroupStory,
                  child: Text('Start Group Story')),
              PopupMenuItem(
                  value: _MenuOption.viewFullStory,
                  child: Text('View Full Story')),
              PopupMenuItem(
                  value: _MenuOption.saveStory,
                  child: Text('Save Story')),
              PopupMenuItem(
                  value: _MenuOption.logout,
                  child: Text('Logout')),
              PopupMenuItem(
                  value: _MenuOption.closeMenu,
                  child: Text('Close Menu')),
            ],
          ),
        ],
      ),

      body: LayoutBuilder(
        builder: (_, __) => Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 800),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  // ─── story text area ───
                  Expanded(
                    child: StoryTextArea(
                      controller: _scrollCtrl,
                      textController: _textCtrl,
                    ),
                  ),

                  const SizedBox(height: 20),

                  // ─── choose next action ───
                  ActionButton(
                    label: 'Choose Next Action',
                    busy: _busy,
                    onPressed: canPick ? () => _showOptionSheet(context) : null,
                  ),

                  // ─── host “take everyone back” ───
                  if (_isMultiplayer && _isHost && (_inLobbyCount > 0 || _phase == StoryPhase.lobby)) ...[
                    const SizedBox(height: 10),
                    ActionButton(
                      label: 'Take Everyone to Story',
                      busy: _busy,
                      onPressed: _hostBringEveryoneBack,
                    ),
                  ],

                  // ─── voting in progress UI ───
                  if (_isMultiplayer && _phase == StoryPhase.vote) ...[
                    const SizedBox(height: 20),
                    _busy
                        ? const CircularProgressIndicator()
                        : Text(
                      'Waiting for votes…',
                      style: GoogleFonts.atma(fontSize: 16),
                      textAlign: TextAlign.center,
                    ),
                    if (_isHost && !_busy) ...[
                      const SizedBox(height: 10),
                      ActionButton(
                        label: 'Resolve Votes',
                        busy: _busy,
                        onPressed: _resolveAndAdvance,
                      ),
                    ],
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
