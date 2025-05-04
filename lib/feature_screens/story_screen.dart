// lib/screens/story_screen.dart
// -----------------------------------------------------------------------------
// Main reading / interaction screen (solo + multiplayer).
// All colours & fonts are pulled from ThemeData so the view adapts to the
// palette & font chosen in Profile → Theme.
// -----------------------------------------------------------------------------

import 'package:flutter/material.dart';
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
import 'mutiplayer_screens/multiplayer_host_lobby_screen.dart';

enum _MenuOption {
  backToScreen,
  startGroupStory,
  viewFullStory,
  saveStory,
  logout,
  closeMenu,
}

class StoryScreen extends StatefulWidget {
  const StoryScreen({
    super.key,
    required this.initialLeg,
    required this.options,
    required this.storyTitle,
    this.sessionId,
    this.joinCode,
    this.inputTokens      = 0,
    this.outputTokens     = 0,
    this.estimatedCostUsd = 0.0,
  });

  final String initialLeg;
  final List<String> options;
  final String storyTitle;
  final String? sessionId;   // null ⇒ solo
  final String? joinCode;
  final int    inputTokens;
  final int    outputTokens;
  final double estimatedCostUsd;

  @override
  State<StoryScreen> createState() => _StoryScreenState();
}

/* ───────────────────────────────────────────────────────────────────── */

class _StoryScreenState extends State<StoryScreen> {
  late final StoryController ctrl;

  final ScrollController _scrollCtrl = ScrollController();
  late final TextEditingController _txtCtrl;

  final _authSvc  = AuthService();
  final _storySvc = StoryService();
  final _lobbySvc = LobbyRtdbService();

  @override
  void initState() {
    super.initState();
    ctrl = StoryController(
      initialLeg    : widget.initialLeg,
      initialOptions: widget.options,
      storyTitle    : widget.storyTitle,
      sessionId     : widget.sessionId,
      joinCode      : widget.joinCode,
      initialInputTokens     : widget.inputTokens,
      initialOutputTokens    : widget.outputTokens,
      initialEstimatedCostUsd: widget.estimatedCostUsd,
      onError : _showError,
      onInfo  : _showSnack,
      onKicked: _handleKick,
    );

    _txtCtrl = TextEditingController(text: ctrl.text);

    ctrl.addListener(() {
      if (_txtCtrl.text != ctrl.text) {
        _txtCtrl.text = ctrl.text;
        _scrollCtrl.jumpTo(0);
      }
      setState(() {});      // refresh badges / buttons
    });
  }

  @override
  void dispose() {
    ctrl.disposeController();
    _txtCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  /* ───────── snack / error helpers ───────── */

  void _showSnack(String m) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(m, style: tt.bodyMedium?.copyWith(color: cs.onPrimary)),
        backgroundColor: cs.primary,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
  void _showError(String m) => showError(context, m);

  /* ───────── option sheet + back-one-leg ───────── */

  void _optionSheet() {
    final canPick = !ctrl.busy &&
        (ctrl.phase == StoryPhase.story || ctrl.phase == StoryPhase.vote) &&
        ctrl.inLobby == 0;
    if (!canPick) return;

    showModalBottomSheet(
      context: context,
      builder: (_) => NextActionSheet(
        options     : ctrl.options,
        busy        : ctrl.busy,
        onPrevious  : _confirmBack,
        onSelect    : ctrl.chooseNext,
      ),
    );
  }

  Future<void> _confirmBack() async {
    final ok = await confirmDialog(
      ctx  : context,
      title: 'Warning',
      message:
      'If you go back and then pick the same option, the next leg may differ. Continue?',
    );
    if (ok) await ctrl.backOneLeg();
  }

  /* ───────── kicked from multiplayer ───────── */

  Future<void> _handleKick() async {
    if (!mounted) return;
    _showSnack('You were removed from the session.');
    Navigator.pushReplacement(
        context, MaterialPageRoute(builder: (_) => const HomeScreen()));
  }

  /* ───────── menu helpers ───────── */

  Future<void> _showFullStory() async {
    try {
      final res = await _storySvc.getFullStory(
        sessionId:
        (ctrl.isMultiplayer && !ctrl.isHost) ? widget.sessionId : null,
      );
      if (!mounted) return;

      showDialog(
        context: context,
        builder: (_) => FullStoryDialog(
          storyText: res['initialLeg'] ?? '',
          choiceOptions: List<String>.from(res['options'] ?? []),
          isChoiceSelectable: !ctrl.busy &&
              (ctrl.phase == StoryPhase.story || ctrl.phase == StoryPhase.vote),
          onChoiceSelected: (opt) {
            Navigator.pop(context);
            ctrl.chooseNext(opt);
          },
          onShowChoices: () {
            Navigator.pop(context);
            _optionSheet();
          },
        ),
      );
    } catch (e) {
      _showError('$e');
    }
  }

  Future<void> _saveStory() async {
    try {
      final r = await _storySvc.saveStory(
        sessionId:
        (ctrl.isMultiplayer && !ctrl.isHost) ? widget.sessionId : null,
      );
      _showSnack(r['message'] ?? 'Story saved.');
    } catch (e) {
      _showError('$e');
    }
  }

  /* ───────── convert solo → group or back to lobby ───────── */

  Future<void> _createGroupSession() async {
    setState(() {}); // show spinner if you add one later
    try {
      if (!ctrl.isMultiplayer) {
        final backend      = await _storySvc.createMultiplayerSession("false");
        final newSessionId = backend['sessionId'] as String;
        final newJoinCode  = backend['joinCode']  as String;

        // seed lobby
        final hostName = FirebaseAuth.instance.currentUser?.displayName ?? 'Host';
        await _lobbySvc.createSession(
          sessionId     : newSessionId,
          hostName      : hostName,
          randomDefaults: {},
          newGame       : false,
        );

        // broadcast current solo story (incl. counters)
        await _lobbySvc.advanceToStoryPhase(
          sessionId: newSessionId,
          storyPayload: {
            'initialLeg'      : widget.initialLeg,
            'options'         : widget.options,
            'storyTitle'      : widget.storyTitle,
            'inputTokens'     : ctrl.inputTokens,
            'outputTokens'    : ctrl.outputTokens,
            'estimatedCostUsd': ctrl.estimatedCostUsd,
          },
        );

        final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
        final map = <int, Map<String, dynamic>>{
          1: {'displayName': hostName, 'userId': uid},
        };

        await _lobbySvc.updatePhase(
          sessionId: newSessionId,
          phase    : StoryPhase.lobby.asString,
          isNewGame: false,
        );

        if (!mounted) return;
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => MultiplayerHostLobbyScreen(
              sessionId     : newSessionId,
              joinCode      : newJoinCode,
              playersMap    : map,
              fromSoloStory : true,
              fromGroupStory: false,
            ),
          ),
        );
      } else {
        // already MP → go back to lobby
        final map = await _lobbySvc.fetchPlayerList(
            sessionId: widget.sessionId!);
        await _lobbySvc.updatePhase(
          sessionId: widget.sessionId!,
          phase    : StoryPhase.lobby.asString,
          isNewGame: false,
        );
        if (!mounted) return;
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => MultiplayerHostLobbyScreen(
              sessionId     : widget.sessionId!,
              joinCode      : widget.joinCode!,
              playersMap    : map,
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

  /* ───────── build ───────── */

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    final canPick = !ctrl.busy &&
        (ctrl.phase == StoryPhase.story || ctrl.phase == StoryPhase.vote) &&
        ctrl.inLobby == 0;

    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        backgroundColor: cs.primary.withOpacity(.5),
        elevation: 8,
        centerTitle: true,
        title: FittedBox(
          fit: BoxFit.scaleDown,
          child: Column(
            children: [
              Text(ctrl.title,
                  style: tt.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
              Text('${ctrl.inputTokens} tokens • \$'
                  '${ctrl.estimatedCostUsd.toStringAsFixed(4)}',
                  style: tt.bodySmall),
            ],
          ),
        ),
        actions: [
          PopupMenuButton<_MenuOption>(
            icon: Icon(Icons.menu, color: cs.onPrimary),
            itemBuilder: (_) => const [
              PopupMenuItem(value: _MenuOption.backToScreen,
                  child: Text('Back to Home')),
              PopupMenuItem(value: _MenuOption.startGroupStory,
                  child: Text('Multiplayer Lobby')),
              PopupMenuItem(value: _MenuOption.viewFullStory,
                  child: Text('View Full Story')),
              PopupMenuItem(value: _MenuOption.saveStory,
                  child: Text('Save Story')),
              PopupMenuItem(value: _MenuOption.logout,
                  child: Text('Logout')),
              PopupMenuItem(value: _MenuOption.closeMenu,
                  child: Text('Close Menu')),
            ],
            onSelected: (ch) async {
              switch (ch) {
                case _MenuOption.backToScreen:
                  Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(builder: (_) => const HomeScreen()));
                  break;
                case _MenuOption.startGroupStory:
                  await _createGroupSession();
                  break;
                case _MenuOption.viewFullStory:
                  await _showFullStory();
                  break;
                case _MenuOption.saveStory:
                  await _saveStory();
                  break;
                case _MenuOption.logout:
                  await _authSvc.signOut();
                  if (!mounted) return;
                  Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(
                          builder: (_) => const MainSplashScreen()));
                  break;
                case _MenuOption.closeMenu:
                  break;
              }
            },
          ),
        ],
      ),

      body: Stack(
        children: [
          Positioned.fill(
              child: Image.asset('assets/parchment_updated.png',
                  fit: BoxFit.cover)),
          SafeArea(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 800),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      Expanded(
                        child: StoryTextArea(
                          controller     : _scrollCtrl,
                          textController : _txtCtrl,
                        ),
                      ),
                      const SizedBox(height: 20),
                      ActionButton(
                        label: 'Choose Next Action',
                        busy : ctrl.busy,
                        onPressed: canPick ? _optionSheet : null,
                      ),
                      if (ctrl.isMultiplayer &&
                          ctrl.phase == StoryPhase.vote) ...[
                        const SizedBox(height: 20),
                        if (ctrl.isHost && !ctrl.busy)
                          ...[
                            ActionButton(
                              label: 'Resolve Votes',
                              busy : ctrl.busy,
                              onPressed: ctrl.resolveVotesManually,
                            ),
                            const SizedBox(height: 10),
                          ],
                        ctrl.busy
                            ? const CircularProgressIndicator()
                            : Text('Waiting for votes…',
                            style: tt.bodyLarge,
                            textAlign: TextAlign.center),
                      ],
                      if (ctrl.isMultiplayer &&
                          ctrl.isHost &&
                          (ctrl.inLobby > 0 ||
                              ctrl.phase == StoryPhase.lobby)) ...[
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
          ),
        ],
      ),
    );
  }
}
