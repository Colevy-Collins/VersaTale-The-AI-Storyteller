import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import '../services/auth_service.dart';
import '../services/story_service.dart';
import '../services/lobby_rtdb_service.dart';
import 'main_splash_screen.dart';

// Menu options
enum _MenuOption {
  backToScreen,
  previousLeg,
  viewFullStory,
  saveStory,
  logout,
  closeMenu,
}

/// Unified story screen: solo or multiplayer (voting).
/// Pass [sessionId] to enable group voting.
class StoryScreen extends StatefulWidget {
  final String initialLeg;
  final List<String> options;
  final String storyTitle;
  final String? sessionId; // null = solo, non-null = multiplayer

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
  final AuthService authService    = AuthService();
  final StoryService storyService  = StoryService();
  final LobbyRtdbService _lobbySvc = LobbyRtdbService();

  final TextEditingController textController = TextEditingController();
  final ScrollController _scrollController    = ScrollController();
  StreamSubscription<DatabaseEvent>? _lobbySub;

  late List<String> currentOptions;
  String _storyTitle           = "Interactive Story";
  String _phase                = 'story';
  bool   _isRequestInProgress  = false;
  Map<String, dynamic> _players = {};

  bool get isMultiplayer => widget.sessionId != null;
  bool get isHost {
    final info = _players['1'];
    return info is Map && info['userId'] == FirebaseAuth.instance.currentUser?.uid;
  }

  @override
  void initState() {
    super.initState();
    textController.text   = widget.initialLeg;
    currentOptions        = widget.options;
    _storyTitle           = widget.storyTitle;

    if (isMultiplayer) {
      _lobbySub = _lobbySvc
          .lobbyStream(widget.sessionId!)
          .listen(_onLobbyUpdate);
    }
  }

  void _onLobbyUpdate(DatabaseEvent event) {
    final root = (event.snapshot.value as Map?)?.cast<dynamic, dynamic>() ?? {};

    /* ── 1.  Normalize the players node ─────────────────────────────────── */
    _players = _normalizePlayers(root['players']);

    /* ── 2.  Phase change detection ─────────────────────────────────────── */
    final newPhase = root['phase']?.toString() ?? 'story';
    if (newPhase != _phase) {
      setState(() => _phase = newPhase);
    }

    /* ── 3.  Auto‑resolve if host and everyone has voted ────────────────── */
    if (_phase == 'storyVote' && isHost && !_isRequestInProgress) {
      final voteCount   = _normalizePlayers(root['storyVotes']).length;
      final playerCount = _players.length;
      if (playerCount > 0 && voteCount >= playerCount) {
        _resolveAndAdvance();   // tally + broadcast
      }
    }

    /* ── 4.  When new story arrives, update UI ──────────────────────────── */
    if (_phase == 'story' && root['storyPayload'] != null) {
      final payload = (root['storyPayload'] as Map).cast<String, dynamic>();
      setState(() {
        textController.text = payload['initialLeg'] as String;
        currentOptions      = List<String>.from(payload['options'] as List);
        _storyTitle         = payload['storyTitle'] as String;
      });
      _scrollController.jumpTo(0.0);
    }
  }

  /// Convert the raw `players` node (Map OR List) into a
  /// canonical Map<String,dynamic> whose keys are the slot numbers.
  Map<String, dynamic> _normalizePlayers(dynamic raw) {
    final Map<String, dynamic> out = {};
    if (raw is Map) {
      raw.forEach((k, v) => out[k.toString()] = v);
    } else if (raw is List) {
      for (var i = 0; i < raw.length; i++) {
        final entry = raw[i];
        if (entry is Map) out['$i'] = entry;
      }
    }
    return out;
  }

  /// Submit or overwrite your vote
  Future<void> _submitVote(String choice) async {
    setState(() => _isRequestInProgress = true);
    try {
      await _lobbySvc.submitStoryVote(
        sessionId: widget.sessionId!,
        vote: choice,
      );
    } catch (e) {
      showErrorDialog(context, '$e');
    } finally {
      setState(() => _isRequestInProgress = false);
    }
  }

  /// Host tally & broadcast next leg
  Future<void> _resolveAndAdvance() async {
    setState(() => _isRequestInProgress = true);
    try {
      final winner = await _lobbySvc.resolveStoryVotes(widget.sessionId!);
      final res    = await storyService.getNextLeg(decision: winner);
      await _lobbySvc.advanceToStoryPhase(
        sessionId: widget.sessionId!,
        storyPayload: {
          'initialLeg': res['storyLeg'],
          'options':    List<String>.from(res['options'] ?? []),
          'storyTitle': res['storyTitle'],
        },
      );
    } catch (e) {
      showErrorDialog(context, '$e');
    } finally {
      setState(() => _isRequestInProgress = false);
    }
  }

  /// “Previous Leg” confirmation
  Future<void> _confirmAndGoBack() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text("Warning", style: GoogleFonts.atma()),
        content: Text(
          "If you go back and then choose the same option, the next leg may be different. Continue?",
          style: GoogleFonts.atma(),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text("Cancel", style: GoogleFonts.atma())),
          TextButton(onPressed: () => Navigator.pop(context, true),  child: Text("Continue", style: GoogleFonts.atma())),
        ],
      ),
    );
    if (ok == true) {
      if (isMultiplayer) {
        await _submitVote('<<PREVIOUS_LEG>>');
      } else {
        _soloPreviousLeg();
      }
    }
  }

  /// Solo “Previous Leg”
  Future<void> _soloPreviousLeg() async {
    if (_isRequestInProgress) return;
    setState(() => _isRequestInProgress = true);
    try {
      final resp = await storyService.getPreviousLeg();
      textController.text    = resp['storyLeg'] ?? 'No story leg returned.';
      currentOptions         = List<String>.from(resp['options'] ?? []);
      if (resp.containsKey('storyTitle')) _storyTitle = resp['storyTitle'];
    } catch (e) {
      showErrorDialog(context, '$e');
    } finally {
      setState(() => _isRequestInProgress = false);
      _scrollController.jumpTo(0.0);
    }
  }

  /// Dispatch menu actions
  Future<void> _onMenuSelected(_MenuOption opt) async {
    switch (opt) {
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
        await authService.signOut();
        Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => MainSplashScreen()));
        break;
      case _MenuOption.closeMenu:
        break;
    }
  }

  /// Show full story dialog
  void _showFullStory() async {
    try {
      final resp = await storyService.getFullStory();
      final full = resp['initialLeg'] ?? 'Your story will appear here';
      final opts = List<String>.from(resp['options'] ?? []);
      showDialog(
        context: context,
        builder: (_) => FullStoryDialog(
          fullStory: full,
          dialogOptions: opts,
          onOptionSelected: (opt) {
            Navigator.pop(context);
            _onNextSelected(opt);
          },
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    }
  }

  /// Save story
  void _saveStory() async {
    try {
      final resp = await storyService.saveStory();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(resp['message'] ?? 'Story saved successfully.', style: GoogleFonts.atma()),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e', style: GoogleFonts.atma())));
    }
  }

  /// Handle “Next” or voting
  void _onNextSelected(String decision) async {
    // Multiplayer: first tap writes vote+phase
    if (isMultiplayer && _phase == 'story') {
      setState(() => _isRequestInProgress = true);
      try {
        await Future.wait([
          _lobbySvc.updatePhase(sessionId: widget.sessionId!, phase: 'storyVote'),
          _lobbySvc.submitStoryVote(sessionId: widget.sessionId!, vote: decision),
        ]);
      } catch (e) {
        showErrorDialog(context, '$e');
      } finally {
        setState(() => _isRequestInProgress = false);
      }
      return;
    }

    // Multiplayer: if already in vote phase, let them change vote
    if (isMultiplayer && _phase == 'storyVote') {
      await _submitVote(decision);
      return;
    }

    // Solo flow
    setState(() => _isRequestInProgress = true);
    try {
      final resp = await storyService.getNextLeg(decision: decision);
      textController.text    = resp['storyLeg'] ?? 'No story leg returned.';
      currentOptions         = List<String>.from(resp['options'] ?? []);
      if (resp.containsKey('storyTitle')) _storyTitle = resp['storyTitle'];
    } catch (e) {
      showErrorDialog(context, '$e');
    } finally {
      setState(() => _isRequestInProgress = false);
      _scrollController.jumpTo(0.0);
    }
  }

  @override
  void dispose() {
    _lobbySub?.cancel();
    textController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        backgroundColor: Colors.white.withOpacity(0.7),
        elevation: 8,
        centerTitle: true,
        title: FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(_storyTitle, style: GoogleFonts.atma(fontWeight: FontWeight.bold, color: Colors.black)),
        ),
        actions: [
          PopupMenuButton<_MenuOption>(
            icon: const Icon(Icons.menu, color: Colors.black),
            onSelected: _onMenuSelected,
            itemBuilder: (_) => [
              PopupMenuItem(value: _MenuOption.backToScreen, child: Text('Back a Screen', style: GoogleFonts.atma())),
              PopupMenuItem(value: _MenuOption.previousLeg,   child: Text('Previous Leg',    style: GoogleFonts.atma())),
              PopupMenuItem(value: _MenuOption.viewFullStory, child: Text('View Full Story', style: GoogleFonts.atma())),
              PopupMenuItem(value: _MenuOption.saveStory,     child: Text('Save Story',      style: GoogleFonts.atma())),
              PopupMenuItem(value: _MenuOption.logout,        child: Text('Logout',          style: GoogleFonts.atma())),
              PopupMenuItem(value: _MenuOption.closeMenu,     child: Text('Close Menu',      style: GoogleFonts.atma())),
            ],
          ),
        ],
      ),
      body: LayoutBuilder(
        builder: (_, __) => Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 800),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Scrollbar(
                        controller: _scrollController,
                        child: SingleChildScrollView(
                          controller: _scrollController,
                          child: TextField(
                            controller: textController,
                            maxLines: null,
                            readOnly: true,
                            decoration: const InputDecoration.collapsed(hintText: "Story will appear here..."),
                            style: GoogleFonts.atma(),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Solo “Choose Next Action” or first‑tap in multiplayer
                  if (currentOptions.isNotEmpty && (_phase == 'story' || _phase == 'storyVote'))
                    ElevatedButton(
                      onPressed: _isRequestInProgress
                          ? null
                          : () => showButtonMenu(context), // <- only opens sheet now
                      style: ElevatedButton.styleFrom(minimumSize: const Size.fromHeight(48)),
                      child: _isRequestInProgress
                          ? const CircularProgressIndicator()
                          : Text('Choose Next Action', style: GoogleFonts.atma(fontWeight: FontWeight.bold)),
                    ),

                  // Multiplayer voting UI
                  if (isMultiplayer && _phase == 'storyVote') ...[
                    const SizedBox(height: 20),
                    if (_isRequestInProgress)
                      CircularProgressIndicator(),
                    if (!_isRequestInProgress)
                      Text('Waiting for votes…', style: GoogleFonts.atma(fontSize: 16), textAlign: TextAlign.center),
                    if (isHost && !_isRequestInProgress) ...[
                      const SizedBox(height: 10),
                      ElevatedButton(
                        onPressed: _resolveAndAdvance,
                        style: ElevatedButton.styleFrom(minimumSize: const Size.fromHeight(48)),
                        child: Text('Resolve Votes', style: GoogleFonts.atma(fontWeight: FontWeight.bold)),
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

  /// Bottom sheet for showing the current options.
  void showButtonMenu(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (_) => Container(
        height: 250,
        child: ListView.builder(
          itemCount: currentOptions.length,
          itemBuilder: (_, idx) {
            final choice = currentOptions[idx];
            final isFinal = choice == 'The story ends';
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 16),
              child: ElevatedButton(
                onPressed: _isRequestInProgress || isFinal
                    ? null
                    : () {
                  Navigator.pop(context);
                  _onNextSelected(choice);
                },
                style: ElevatedButton.styleFrom(minimumSize: const Size.fromHeight(48)),
                child: Text(isFinal ? 'The story ends' : choice,
                    style: GoogleFonts.atma(fontWeight: FontWeight.bold)),
              ),
            );
          },
        ),
      ),
    );
  }
}

/// Full‑story dialog
class FullStoryDialog extends StatefulWidget {
  final String fullStory;
  final List<String> dialogOptions;
  final ValueChanged<String> onOptionSelected;

  const FullStoryDialog({
    Key? key,
    required this.fullStory,
    required this.dialogOptions,
    required this.onOptionSelected,
  }) : super(key: key);

  @override
  _FullStoryDialogState createState() => _FullStoryDialogState();
}

class _FullStoryDialogState extends State<FullStoryDialog> {
  final ScrollController _dialogScrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance?.addPostFrameCallback((_) {
      if (_dialogScrollController.hasClients) {
        _dialogScrollController.jumpTo(_dialogScrollController.position.maxScrollExtent);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Full Story So Far', style: GoogleFonts.atma()),
      content: Container(
        height: 300,
        width: double.maxFinite,
        child: Scrollbar(
          controller: _dialogScrollController,
          child: SingleChildScrollView(
            controller: _dialogScrollController,
            child: Text(widget.fullStory, style: GoogleFonts.atma()),
          ),
        ),
      ),
      actions: [
        if (widget.dialogOptions.isNotEmpty)
          ElevatedButton(
            onPressed: () {
              showModalBottomSheet(
                context: context,
                builder: (_) => Container(
                  height: 250,
                  child: ListView.builder(
                    itemCount: widget.dialogOptions.length,
                    itemBuilder: (_, idx) {
                      final opt = widget.dialogOptions[idx];
                      final isFinal = opt == 'The story ends';
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 16),
                        child: ElevatedButton(
                          onPressed: isFinal
                              ? null
                              : () {
                            widget.onOptionSelected(opt);
                            Navigator.pop(context);
                          },
                          style: ElevatedButton.styleFrom(minimumSize: const Size.fromHeight(48)),
                          child: Text(isFinal ? 'The story ends' : opt,
                              style: GoogleFonts.atma(fontWeight: FontWeight.bold)),
                        ),
                      );
                    },
                  ),
                ),
              );
            },
            child: Text('Choose Next Action', style: GoogleFonts.atma()),
          ),
        TextButton(onPressed: () => Navigator.pop(context), child: Text('Close', style: GoogleFonts.atma())),
      ],
    );
  }
}

/// Error dialog helper
void showErrorDialog(BuildContext context, String message) {
  showDialog(
    context: context,
    builder: (_) => AlertDialog(
      title: const Text('Error'),
      content: Text(message),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close')),
      ],
    ),
  );
}
