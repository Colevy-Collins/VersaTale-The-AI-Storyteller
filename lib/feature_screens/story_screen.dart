// lib/screens/story_screen.dart
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../controllers/story_controller.dart';
import '../models/story_phase.dart';
import '../utils/ui_utils.dart';

import '../services/auth_service.dart';
import '../services/story_service.dart';
import '../services/lobby_rtdb_service.dart';

import '../widgets/action_button.dart';
import '../widgets/next_action_sheet.dart';
import '../widgets/story_text_area.dart';
import '../widgets/full_story_dialog.dart';

import 'dashboard_screen.dart';
import '../feature_screens/login_screens/main_splash_screen.dart';
import '../feature_screens/mutiplayer_screens/multiplayer_host_lobby_screen.dart';

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
  final String? sessionId; // null ⇒ solo
  final String? joinCode;

  const StoryScreen({
    super.key,
    required this.initialLeg,
    required this.options,
    required this.storyTitle,
    this.sessionId,
    this.joinCode,
  });

  @override
  State<StoryScreen> createState() => _StoryScreenState();
}

class _StoryScreenState extends State<StoryScreen> {
  // ─── controller (business logic) ────────────────────────────────────────────
  late final StoryController ctrl;

  // ─── UI controllers ────────────────────────────────────────────────────────
  final ScrollController _scrollCtrl = ScrollController();
  late final TextEditingController _txtCtrl;

  // ─── service singletons (needed only for menu helpers) ─────────────────────
  final _authSvc   = AuthService();
  final _storySvc  = StoryService();
  final _lobbySvc  = LobbyRtdbService();

  @override
  void initState() {
    super.initState();

    ctrl = StoryController(
      initialLeg    : widget.initialLeg,
      initialOptions: widget.options,
      storyTitle    : widget.storyTitle,
      sessionId     : widget.sessionId,
      joinCode      : widget.joinCode,
      onError:   (m) => _showError(m),
      onInfo :   (m) => _showSnack(m),
      onKicked      : _handleKick,
    );

    _txtCtrl = TextEditingController(text: ctrl.text);

    // keep StoryTextArea in sync with the controller’s text
    ctrl.addListener(() {
      if (_txtCtrl.text != ctrl.text) {
        _txtCtrl.text = ctrl.text;
        _scrollCtrl.jumpTo(0);
      }
      setState(() {}); // rebuild for other updated fields
    });
  }

  @override
  void dispose() {
    ctrl.disposeController();
    _txtCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  // ───────────────────────── helpers for snackbars / dialogs ─────────────────
  void _showSnack(String msg) => showSnack(context, msg);        // ← new
  void _showError(String msg) => showError(context, msg);        // ← new

  // ─────────────────────────── UI: option sheet ──────────────────────────────
  void _showOptionSheet() {
    final canPick = !ctrl.busy &&
        (ctrl.phase == StoryPhase.story || ctrl.phase == StoryPhase.vote) &&
        ctrl.inLobby == 0;
    if (!canPick) return;

    showModalBottomSheet(
      context: context,
      builder: (_) => NextActionSheet(
        options: ctrl.options,
        busy   : ctrl.busy,
        onPrevious: _confirmAndGoBack,
        onSelect  : ctrl.chooseNext,
      ),
    );
  }

  // ─────────────────────────── UI: kick from session ─────────────────────────
  void _handleKick() {
    if (!mounted) return;

    _showSnack('You were removed from the session.');

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => HomeScreen()),
    );
  }


  // ───────────────────────── previous‑leg confirmation ────────────────────────
  Future<void> _confirmAndGoBack() async {                         // ← new
    final ok = await confirmDialog(
      ctx: context,
      title: 'Warning',
      message:
      'If you go back and then choose the same option, the next leg may differ. Continue?',
    );
    if (ok) await ctrl.backOneLeg();
  }

  // ─────────────────────────── MENU ACTIONS ──────────────────────────────────

  // full‑story dialog
  Future<void> _showFullStory() async {
    try {
      final res = await _storySvc.getFullStory(
        sessionId: (ctrl.isMultiplayer && !ctrl.isHost) ? widget.sessionId : null,
      );

      if (!mounted) return;

      showDialog(
        context: context,
        builder: (_) => FullStoryDialog(
          fullStory      : res['initialLeg'] ?? '',
          dialogOptions  : List<String>.from(res['options'] ?? []),
          canPick        : !ctrl.busy &&
              (ctrl.phase == StoryPhase.story ||
                  ctrl.phase == StoryPhase.vote),
          onOptionSelected: (opt) {
            Navigator.pop(context);
            ctrl.chooseNext(opt);
          },
          onShowOptions: () {
            Navigator.pop(context);
            _showOptionSheet();
          },
        ),
      );
    } catch (e) {
      _showError('$e');
    }
  }

  // save story to backend
  Future<void> _saveStory() async {
    try {
      final r = await _storySvc.saveStory(
        sessionId: (ctrl.isMultiplayer && !ctrl.isHost) ? widget.sessionId : null,
      );
      _showSnack(r['message'] ?? 'Story saved.');
    } catch (e) {
      _showError('$e');
    }
  }

  // create or resume a multiplayer lobby (copied from original implementation)
  Future<void> _createGroupSession() async {
    setState(() => ctrl.loading == true);
    try {
      if (!ctrl.isMultiplayer) {
        // 1) create session on backend
        final backend = await _storySvc.createMultiplayerSession("false");
        final newSessionId = backend['sessionId'] as String;
        final newJoinCode  = backend['joinCode']  as String;

        // 2) seed RTDB lobby
        final hostName = FirebaseAuth.instance.currentUser?.displayName ?? 'Host';
        await _lobbySvc.createSession(
          sessionId: newSessionId,
          hostName : hostName,
          randomDefaults: {},
          newGame: false,
        );

        // 3) broadcast current solo story
        await _lobbySvc.advanceToStoryPhase(
          sessionId: newSessionId,
          storyPayload: {
            'initialLeg': widget.initialLeg,
            'options'   : widget.options,
            'storyTitle': widget.storyTitle,
          },
        );

        // 4) minimal players map
        final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
        final playersMap = <int, Map<String, dynamic>>{
          1: {'displayName': hostName, 'userId': uid},
        };

        // 5) switch lobby to “lobby” phase
        await _lobbySvc.updatePhase(
          sessionId: newSessionId,
          phase:     StoryPhase.lobby.asString,
        );

        // 6) navigate host lobby
        if (!mounted) return;
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => MultiplayerHostLobbyScreen(
              sessionId     : newSessionId,
              joinCode      : newJoinCode,
              playersMap    : playersMap,
              fromSoloStory : true,
              fromGroupStory: false,
            ),
          ),
        );
      } else {
        // already multiplayer ⇒ just hop to lobby
        final playersMap = await _lobbySvc.fetchPlayerList(
          sessionId: widget.sessionId!,
        );

        await _lobbySvc.updatePhase(
          sessionId: widget.sessionId!,
          phase:     StoryPhase.lobby.asString,
        );

        if (!mounted) return;
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => MultiplayerHostLobbyScreen(
              sessionId     : widget.sessionId!,
              joinCode      : widget.joinCode!,
              playersMap    : playersMap,
              fromSoloStory : false,
              fromGroupStory: true,
            ),
          ),
        );
      }
    } catch (e) {
      _showError('Error creating session: $e');
    } finally {
      if (mounted) setState(() {});
    }
  }

  // ─────────────────────────── WIDGET TREE ────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final canPick = !ctrl.busy &&
        (ctrl.phase == StoryPhase.story || ctrl.phase == StoryPhase.vote) &&
        ctrl.inLobby == 0;

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        backgroundColor: Colors.white.withOpacity(0.7),
        elevation: 8,
        centerTitle: true,
        title: FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            ctrl.title,
            style: GoogleFonts.atma(
              fontWeight: FontWeight.bold,
              color: Colors.black,
            ),
          ),
        ),
        actions: [
          PopupMenuButton<_MenuOption>(
            icon: const Icon(Icons.menu, color: Colors.black),
            onSelected: (choice) async {
              switch (choice) {
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
                  if (!mounted) return;
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
                child: Text('Back a Screen'),
              ),
              PopupMenuItem(
                value: _MenuOption.startGroupStory,
                child: Text('Start Group Story'),
              ),
              PopupMenuItem(
                value: _MenuOption.viewFullStory,
                child: Text('View Full Story'),
              ),
              PopupMenuItem(
                value: _MenuOption.saveStory,
                child: Text('Save Story'),
              ),
              PopupMenuItem(
                value: _MenuOption.logout,
                child: Text('Logout'),
              ),
              PopupMenuItem(
                value: _MenuOption.closeMenu,
                child: Text('Close Menu'),
              ),
            ],
          ),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 800),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                // ── story text area ──
                Expanded(
                  child: StoryTextArea(
                    controller: _scrollCtrl,
                    textController: _txtCtrl,
                  ),
                ),
                const SizedBox(height: 20),
                // ── choose next action ──
                ActionButton(
                  label: 'Choose Next Action',
                  busy: ctrl.busy,
                  onPressed: canPick ? _showOptionSheet : null,
                ),
                // 4. ─── voting in progress UI ───
                if (ctrl.isMultiplayer && ctrl.phase == StoryPhase.vote) ...[
                  const SizedBox(height: 20),
                  ctrl.busy
                      ? const CircularProgressIndicator()
                      : Text(
                    'Waiting for votes…',
                    style: GoogleFonts.atma(fontSize: 16),
                    textAlign: TextAlign.center,
                  ),
                  if (ctrl.isHost && !ctrl.busy) ...[
                    const SizedBox(height: 10),
                    ActionButton(
                      label: 'Resolve Votes',
                      busy : ctrl.busy,
                      onPressed: ctrl.resolveVotesManually,
                    ),
                  ],
                ],
                // ─── NEW: host‑only “Bring Everyone Back” button ───
                if (ctrl.isMultiplayer &&
                    ctrl.isHost &&
                    (ctrl.inLobby > 0 || ctrl.phase == StoryPhase.lobby)) ...[
                  const SizedBox(height: 10),
                  ActionButton(
                    label: 'Bring Everyone Back',
                    busy : ctrl.busy,
                    onPressed: ctrl.hostBringEveryoneBack,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
