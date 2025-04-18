// lib/screens/story_screen.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';

import '../constants/story_tokens.dart';      // ← kPreviousLegToken
import '../services/auth_service.dart';
import '../services/story_service.dart';
import '../services/lobby_rtdb_service.dart';
import 'main_splash_screen.dart';

/* ── App‑bar menu options ─────────────────────────────────────────── */
enum _MenuOption {
  backToScreen,
  previousLeg,
  viewFullStory,
  saveStory,
  logout,
  closeMenu,
}

/* ── Story Screen (solo or multiplayer) ───────────────────────────── */
class StoryScreen extends StatefulWidget {
  final String initialLeg;
  final List<String> options;
  final String storyTitle;
  final String? sessionId; // null = solo, non‑null = multiplayer

  const StoryScreen({
    Key? key,
    required this.initialLeg,
    required this.options,
    required this.storyTitle,
    this.sessionId,
  }) : super(key: key);

  @override
  _StoryScreenState createState() => _StoryScreenState();
}

class _StoryScreenState extends State<StoryScreen> {
  /* Services */
  final AuthService       _authSvc  = AuthService();
  final StoryService      _storySvc = StoryService();
  final LobbyRtdbService  _lobbySvc = LobbyRtdbService();

  /* Controllers */
  final TextEditingController _textCtrl   = TextEditingController();
  final ScrollController      _scrollCtrl = ScrollController();
  StreamSubscription<DatabaseEvent>? _lobbySub;

  /* State */
  late List<String> _currentOptions;
  String _storyTitle = 'Interactive Story';
  String _phase      = 'story';   // story | storyVote | storyVoteResults
  bool   _busy       = false;
  Map<String,dynamic> _players = {};

  /* Convenience */
  bool get _isMultiplayer => widget.sessionId != null;
  bool get _isHost {
    final slot1 = _players['1'];
    return slot1 is Map &&
        slot1['userId'] == FirebaseAuth.instance.currentUser?.uid;
  }

  /* ── Lifecycle ─────────────────────────────────────────────────── */
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

  /* ── Force‑close any modal (bottom‑sheet, dialog, menu) ──────────── */
  void _closeAnyOptionSheet() {
    // Keep popping routes until the page route is current again
    while (ModalRoute.of(context)?.isCurrent == false) {
      Navigator.of(context, rootNavigator: true).pop();
    }
  }

/* ── RTDB listener ─────────────────────────────────────────────── */
  void _onLobbyUpdate(DatabaseEvent event) {
    final root = (event.snapshot.value as Map?)?.cast<dynamic,dynamic>() ?? {};

    // 1. players
    _players = _normalizePlayers(root['players']);

    // 2. phase change handling
    final newPhase = root['phase']?.toString() ?? 'story';

    // ✱ If the lobby just entered voting or vote‑results, close any modal
    final phaseChanged = newPhase != _phase;
    final enteredVotePhase =
        phaseChanged && (newPhase == 'storyVote' || newPhase == 'storyVoteResults');
    if (enteredVotePhase) _closeAnyOptionSheet();

    if (phaseChanged) setState(() => _phase = newPhase);

    // 3. host auto‑resolve
    if (_phase == 'storyVote' && _isHost && !_busy) {
      final voteCount   = _normalizePlayers(root['storyVotes']).length;
      final playerCount = _players.length;
      if (playerCount > 0 && voteCount >= playerCount) {
        _resolveAndAdvance();
      }
    }

    // 4. story payload update
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

  /* ── Helpers ───────────────────────────────────────────────────── */
  Map<String,dynamic> _normalizePlayers(dynamic raw) {
    final out = <String,dynamic>{};
    if (raw is Map) {
      raw.forEach((k,v)=>out[k.toString()] = v);
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
      } catch (_) {/* ignore */}
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

  /* ── Story navigation (solo) ───────────────────────────────────── */
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
      setState(()=>_busy=false);
      _scrollCtrl.jumpTo(0);
    }
  }

  /* ── Voting helpers ────────────────────────────────────────────── */
  Future<void> _submitVote(String choice) async {
    setState(() => _busy = true);
    try {
      await _lobbySvc.submitStoryVote(
        sessionId: widget.sessionId!,
        vote: choice,
      );
      await _maybeAutoResolve();
    } catch (e) {
      _showError('$e');
    } finally {
      setState(() => _busy = false);
    }
  }

  Future<void> _resolveAndAdvance() async {
    _closeAnyOptionSheet();
    setState(() => _busy = true);
    try {
      /* 1️⃣  broadcast 'storyVoteResults' so everybody locks UI */
      await _lobbySvc.updatePhase(
        sessionId: widget.sessionId!,
        phase: 'storyVoteResults',
      );

      /* 2️⃣  decide winner */
      final winner = await _lobbySvc.resolveStoryVotes(widget.sessionId!);

      /* 3️⃣  advance story */
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
      _showError('$e');
      await _rollbackToStoryPhase();
    } finally {
      setState(() => _busy = false);
    }
  }

  /* ── Next‑action tap handler ───────────────────────────────────── */
  Future<void> _onNextSelected(String decision) async {
    _closeAnyOptionSheet();
    // Multiplayer – first vote
    if (_isMultiplayer && _phase == 'story') {
      setState(()=>_busy=true);
      try {
        await Future.wait([
          _lobbySvc.updatePhase(
            sessionId: widget.sessionId!,
            phase: 'storyVote',
          ),
          _lobbySvc.submitStoryVote(
            sessionId: widget.sessionId!,
            vote: decision,
          ),
        ]);
        await _maybeAutoResolve();
      } catch (e) {
        _showError('$e');
        await _rollbackToStoryPhase();
      } finally {
        setState(()=>_busy=false);
      }
      return;
    }

    // Multiplayer – change existing vote
    if (_isMultiplayer && _phase == 'storyVote') {
      await _submitVote(decision);
      return;
    }

    // Solo
    setState(()=>_busy=true);
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
      setState(()=>_busy=false);
      _scrollCtrl.jumpTo(0);
    }
  }

  /* ── Menu actions ──────────────────────────────────────────────── */
  Future<void> _onMenuSelected(_MenuOption m) async {
    switch (m) {
      case _MenuOption.backToScreen:
        Navigator.pop(context);
        break;
      case _MenuOption.previousLeg:
        await _confirmAndGoBack();
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
            context, MaterialPageRoute(builder: (_) => MainSplashScreen()));
        break;
      case _MenuOption.closeMenu:
        break;
    }
  }

  /* ── Confirm “previous leg” ────────────────────────────────────── */
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
            onPressed: ()=>Navigator.pop(context,false),
          ),
          TextButton(
            child: Text('Continue', style: GoogleFonts.atma()),
            onPressed: ()=>Navigator.pop(context,true),
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

  /* ── Full story dialog / save story helpers ────────────────────── */
/* ── Full‑story dialog launcher ─────────────────────────────────── */
  void _showFullStory() async {
    try {
      final r = await _storySvc.getFullStory(
        // non‑host players in multiplayer can only read; host can pass null
        sessionId: _isMultiplayer && !_isHost ? widget.sessionId : null,
      );

      final txt = r['initialLeg'] ?? 'Story will appear here.';
      final ops = List<String>.from(r['options'] ?? []);

      // Re‑use the same “can pick” test as the main button
      final canPick = !_busy && (_phase == 'story' || _phase == 'storyVote');

      showDialog(
        context: context,
        builder: (_) => _FullStoryDialog(
          fullStory       : txt,
          dialogOptions   : ops,
          canPick         : canPick,           // ← NEW
          onOptionSelected: (opt) {
            Navigator.pop(context);            // close dialog
            _onNextSelected(opt);              // act on choice
          },
          onShowOptions: () {
            Navigator.pop(context);            // close dialog
            _showOptionSheet(context);         // open bottom‑sheet
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

  /* ── Build UI ──────────────────────────────────────────────────── */
  @override
  Widget build(BuildContext ctx) {
    final _canPick =
        !_busy && (_phase == 'story' || _phase == 'storyVote');

    return Scaffold(
      appBar: _buildAppBar(),
      body: LayoutBuilder(
        builder: (_,__) => Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 800),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  _buildStoryBox(),
                  const SizedBox(height:20),

                  /* Choose button */
                  ElevatedButton(
                    onPressed: _canPick ? () => _showOptionSheet(ctx) : null,
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size.fromHeight(48),
                    ),
                    child: _busy
                        ? const CircularProgressIndicator()
                        : Text(
                      'Choose Next Action',
                      style: GoogleFonts.atma(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),

                  /* Multiplayer vote‑waiting UI */
                  if (_isMultiplayer && _phase == 'storyVote') ...[
                    const SizedBox(height:20),
                    _busy
                        ? const CircularProgressIndicator()
                        : Text(
                      'Waiting for votes…',
                      style: GoogleFonts.atma(fontSize:16),
                      textAlign: TextAlign.center,
                    ),
                    if (_isHost && !_busy) ...[
                      const SizedBox(height:10),
                      ElevatedButton(
                        onPressed: _resolveAndAdvance,
                        style: ElevatedButton.styleFrom(
                          minimumSize: const Size.fromHeight(48),
                        ),
                        child: Text(
                          'Resolve Votes',
                          style: GoogleFonts.atma(
                            fontWeight: FontWeight.bold,
                          ),
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

  /* ── UI helpers ────────────────────────────────────────────────── */
  PreferredSizeWidget _buildAppBar() => AppBar(
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
        onSelected: _onMenuSelected,
        itemBuilder: (_) => [
          PopupMenuItem(
            value: _MenuOption.backToScreen,
            child: Text('Back a Screen', style: GoogleFonts.atma()),
          ),
          PopupMenuItem(
            value: _MenuOption.previousLeg,
            child: Text('Previous Leg', style: GoogleFonts.atma()),
          ),
          PopupMenuItem(
              value: _MenuOption.viewFullStory,
              child: Text('View Full Story', style: GoogleFonts.atma())),
          PopupMenuItem(
              value: _MenuOption.saveStory,
              child: Text('Save Story', style: GoogleFonts.atma())),
          PopupMenuItem(
              value: _MenuOption.logout,
              child: Text('Logout', style: GoogleFonts.atma())),
          PopupMenuItem(
              value: _MenuOption.closeMenu,
              child: Text('Close Menu', style: GoogleFonts.atma())),
        ],
      ),
    ],
  );

  Widget _buildStoryBox() => Expanded(
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
            maxLines : null,
            readOnly : true,
            decoration: const InputDecoration.collapsed(
              hintText: 'Story will appear here…',
            ),
            style: GoogleFonts.atma(),
          ),
        ),
      ),
    ),
  );

  /* Bottom‑sheet picker */
  /* ── Bottom‑sheet option picker ──────────────────────────────────── */
  void _showOptionSheet(BuildContext ctx) {
    // Use the same gating logic as the main Choose button
    final canPick = !_busy && (_phase == 'story' || _phase == 'storyVote');
    if (!canPick) return;                     // ignore taps when not allowed

    showModalBottomSheet(
      context: ctx,
      builder: (_) => Container(
        height: 300,
        child: ListView(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
          children: [
            ElevatedButton(
              onPressed: _busy ? null : () {
                Navigator.pop(ctx);
                _confirmAndGoBack();
              },
              style: ElevatedButton.styleFrom(
                minimumSize: const Size.fromHeight(48),
              ),
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
                    minimumSize: const Size.fromHeight(48),
                  ),
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

/* ── Full‑story dialog ─────────────────────────────────────────── */
class _FullStoryDialog extends StatefulWidget {
  final String fullStory;
  final List<String> dialogOptions;
  final ValueChanged<String> onOptionSelected;
  final VoidCallback onShowOptions;
  final bool canPick;                        // ← NEW

  const _FullStoryDialog({
    Key? key,
    required this.fullStory,
    required this.dialogOptions,
    required this.onOptionSelected,
    required this.onShowOptions,
    required this.canPick,                   // ← NEW
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
      width : double.maxFinite,
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
          onPressed: widget.canPick ? widget.onShowOptions : null,   // ← LOCK
          child: Text('Choose Next Action', style: GoogleFonts.atma()),
        ),
      TextButton(
        onPressed: () => Navigator.pop(dialogCtx),
        child: Text('Close', style: GoogleFonts.atma()),
      ),
    ],
  );
}