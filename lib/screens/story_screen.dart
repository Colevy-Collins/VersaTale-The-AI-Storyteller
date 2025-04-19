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
import 'main_splash_screen.dart';
import 'multiplayer_host_lobby_screen.dart';

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

  final TextEditingController _textCtrl   = TextEditingController();
  final ScrollController      _scrollCtrl = ScrollController();
  StreamSubscription<DatabaseEvent>? _lobbySub;

  late List<String> _currentOptions;
  String _storyTitle = 'Interactive Story';
  String _phase      = 'story';   // story | storyVote | storyVoteResults
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
    _players = _normalizePlayers(root['players']);

    // 2️⃣ phase change
    final newPhase = root['phase']?.toString() ?? 'story';
    final phaseChanged = newPhase != _phase;

    // → only close when we've moved into vote‑results
    if (phaseChanged && newPhase == 'storyVoteResults') {
      _closeAnyOptionSheet();
    }

    if (phaseChanged) setState(() => _phase = newPhase);

    // 3️⃣ host auto‑resolve
    if (_phase == 'storyVote' && _isHost && !_busy) {
      final voteCount   = _normalizePlayers(root['storyVotes']).length;
      final playerCount = _players.length;
      if (playerCount > 0 && voteCount >= playerCount) {
        _resolveAndAdvance();
      }
    }

    // 4️⃣ payload update
    if (_phase == 'story' && root['storyPayload'] != null) {
      final p = (root['storyPayload'] as Map).cast<String,dynamic>();
      setState(() {
        _textCtrl.text   = p['initialLeg'] as String;
        _currentOptions  = List<String>.from(p['options'] as List);
        _storyTitle      = p['storyTitle'] as String;
      });
      _scrollCtrl.jumpTo(0);
    }
  }
  Map<String,dynamic> _normalizePlayers(dynamic raw) {
    final out = <String,dynamic>{};
    if (raw is Map) {
      raw.forEach((k,v) => out[k.toString()] = v);
    } else if (raw is List) {
      for (var i = 0; i < raw.length; i++) {
        final e = raw[i];
        if (e is Map) out['$i'] = e;
      }
    }
    return out;
  }

  Future<void> _rollbackToStoryPhase() async {
    if (mounted) setState(() => _phase = 'story');
    if (_isMultiplayer) {
      try {
        await _lobbySvc.updatePhase(
          sessionId: widget.sessionId!,
          phase: 'story',
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

    final players = _normalizePlayers(raw['players']);
    final votes   = _normalizePlayers(raw['storyVotes']);
    final phase   = raw['phase']?.toString() ?? '';

    if (phase == 'storyVote' &&
        players.isNotEmpty &&
        votes.length >= players.length) {
      await _resolveAndAdvance();
    }
  }

  void _showError(String msg) => _showSnack(msg, isError: true);
  void _showSnack(String msg, {bool isError = false}) =>
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(msg, style: GoogleFonts.atma()),
          backgroundColor: isError ? Colors.red : null,
        ),
      );

  Future<void> _hostBringEveryoneBack() async {
    if (!_isHost || widget.sessionId == null) return;
    setState(() => _busy = true);

    try {
      // 2 flip back to story phase
      await _lobbySvc.updatePhase(
        sessionId: widget.sessionId!,
        phase: 'story',
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
        phase: 'storyVoteResults',
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
    if (_isMultiplayer && _phase == 'story') {
      setState(() => _busy = true);
      try {
        await _lobbySvc.updatePhase(
          sessionId: widget.sessionId!,
          phase    : 'storyVote',
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
    if (_isMultiplayer && _phase == 'storyVote') {
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
      final canPick = !_busy && (_phase == 'story' || _phase == 'storyVote');
      showDialog(
        context: context,
        builder: (_) => _FullStoryDialog(
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
          phase:     'lobby',
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
          phase:     'lobby',
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

  @override
  Widget build(BuildContext ctx) {
    // allow voting only when:
    //  • not busy
    //  • in the “story” or “storyVote” phase
    //  • nobody is currently in the lobby
    final canPick = !_busy
        && (_phase == 'story' || _phase == 'storyVote')
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
            itemBuilder: (_) => [
              const PopupMenuItem(
                  value: _MenuOption.backToScreen,
                  child: Text('Back a Screen', style: TextStyle())),
              const PopupMenuItem(
                  value: _MenuOption.startGroupStory,
                  child: Text('Start Group Story')),
              const PopupMenuItem(
                  value: _MenuOption.viewFullStory,
                  child: Text('View Full Story')),
              const PopupMenuItem(
                  value: _MenuOption.saveStory,
                  child: Text('Save Story')),
              const PopupMenuItem(
                  value: _MenuOption.logout,
                  child: Text('Logout')),
              const PopupMenuItem(
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
                  // Story text area
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Scrollbar(
                        controller: _scrollCtrl,
                        child: SingleChildScrollView(
                          controller: _scrollCtrl,
                          child: TextField(
                            controller: _textCtrl,
                            maxLines: null,
                            readOnly: true,
                            decoration: const InputDecoration.collapsed(
                                hintText: 'Story will appear here…'),
                            style: GoogleFonts.atma(),
                          ),
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 20),

                  // Choose Next Action (voting) button
                  ElevatedButton(
                    onPressed: canPick ? () => _showOptionSheet(ctx) : null,
                    style: ElevatedButton.styleFrom(
                        minimumSize: const Size.fromHeight(48)),
                    child: _busy
                        ? const CircularProgressIndicator()
                        : Text(
                      'Choose Next Action',
                      style: GoogleFonts.atma(
                          fontWeight: FontWeight.bold),
                    ),
                  ),

                  // NEW: host “Take Everyone to Story” button
                  if (_isMultiplayer && _isHost && (_inLobbyCount > 0 || _phase == "lobby")) ...[
                    const SizedBox(height: 10),
                    ElevatedButton(
                      onPressed: _busy ? null : _hostBringEveryoneBack,
                      style: ElevatedButton.styleFrom(
                          minimumSize: const Size.fromHeight(48)),
                      child: _busy
                          ? const CircularProgressIndicator()
                          : Text(
                        'Take Everyone to Story',
                        style: GoogleFonts.atma(
                            fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],

                  // Waiting / Resolve votes UI
                  if (_isMultiplayer && _phase == 'storyVote') ...[
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
                      ElevatedButton(
                        onPressed: _resolveAndAdvance,
                        style: ElevatedButton.styleFrom(
                            minimumSize: const Size.fromHeight(48)),
                        child: Text(
                          'Resolve Votes',
                          style: GoogleFonts.atma(
                              fontWeight: FontWeight.bold),
                        ),
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


  void _showOptionSheet(BuildContext ctx) {
    final canPick = !_busy && (_phase == 'story' || _phase == 'storyVote');
    if (!canPick) return;

    showModalBottomSheet(
      context: ctx,
      builder: (_) => Container(
        height: 300,
        child: ListView(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
          children: [
            ElevatedButton(
              onPressed: _busy
                  ? null
                  : () {
                Navigator.pop(ctx);
                _confirmAndGoBack();
              },
              style: ElevatedButton.styleFrom(
                  minimumSize: const Size.fromHeight(48)),
              child: Text('Previous Leg',
                  style: GoogleFonts.atma(fontWeight: FontWeight.bold)),
            ),
            const SizedBox(height: 8),
            ..._currentOptions.map((choice) {
              final isFinal = choice == 'The story ends';
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: ElevatedButton(
                  onPressed: (_busy || isFinal)
                      ? null
                      : () {
                    Navigator.pop(ctx);
                    _onNextSelected(choice);
                  },
                  style: ElevatedButton.styleFrom(
                      minimumSize: const Size.fromHeight(48)),
                  child: Text(
                    isFinal ? 'The story ends' : choice,
                    style: GoogleFonts.atma(fontWeight: FontWeight.bold),
                  ),
                ),
              );
            }).toList(),
          ],
        ),
      ),
    );
  }
}

class _FullStoryDialog extends StatefulWidget {
  final String fullStory;
  final List<String> dialogOptions;
  final ValueChanged<String> onOptionSelected;
  final VoidCallback onShowOptions;
  final bool canPick;

  const _FullStoryDialog({
    Key? key,
    required this.fullStory,
    required this.dialogOptions,
    required this.onOptionSelected,
    required this.onShowOptions,
    required this.canPick,
  }) : super(key: key);

  @override
  State<_FullStoryDialog> createState() => _FullStoryDialogState();
}

class _FullStoryDialogState extends State<_FullStoryDialog> {
  final ScrollController _ctrl = ScrollController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_ctrl.hasClients) _ctrl.jumpTo(_ctrl.position.maxScrollExtent);
    });
  }

  @override
  Widget build(BuildContext dialogCtx) => AlertDialog(
    title: Text('Full Story So Far', style: GoogleFonts.atma()),
    content: Container(
      height: 300,
      width: double.maxFinite,
      child: Scrollbar(
        controller: _ctrl,
        child: SingleChildScrollView(
          controller: _ctrl,
          child: Text(widget.fullStory, style: GoogleFonts.atma()),
        ),
      ),
    ),
    actions: [
      if (widget.dialogOptions.isNotEmpty)
        ElevatedButton(
          onPressed: widget.canPick ? widget.onShowOptions : null,
          child: Text('Choose Next Action', style: GoogleFonts.atma()),
        ),
      TextButton(
        onPressed: () => Navigator.pop(dialogCtx),
        child: Text('Close', style: GoogleFonts.atma()),
      ),
    ],
  );
}
