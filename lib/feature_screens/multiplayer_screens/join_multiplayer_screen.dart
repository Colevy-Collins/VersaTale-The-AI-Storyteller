import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../controllers/join_controller.dart';
import '../../utils/ui_utils.dart';
import '../../services/story_service.dart';
import '../../services/lobby_rtdb_service.dart';
import '../../feature_screens/new_story_screens/create_new_story_screen.dart';
import 'multiplayer_host_lobby_screen.dart';

class JoinMultiplayerScreen extends StatelessWidget {
  const JoinMultiplayerScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => JoinController(
        storyService: StoryService(),
        lobbyService: LobbyRtdbService(),
      ),
      child: const _JoinView(),
    );
  }
}

/* ───────────────────────────────────────────────────────────────────── */

class _JoinView extends StatefulWidget {
  const _JoinView({super.key});

  @override
  State<_JoinView> createState() => __JoinViewState();
}

class __JoinViewState extends State<_JoinView> {
  final _codeCtrl = TextEditingController();
  final _nameCtrl = TextEditingController();

  @override
  void dispose() {
    _codeCtrl.dispose();
    _nameCtrl.dispose();
    super.dispose();
  }

  Future<void> _join() async {
    final ctrl  = context.read<JoinController>();
    final code  = _codeCtrl.text.trim().toUpperCase();
    if (code.isEmpty) {
      showSnack(context, 'Please enter a join code.');
      return;
    }

    final name = _nameCtrl.text.trim().isEmpty
        ? 'Player'
        : _nameCtrl.text.trim();

    try {
      final entry      = await ctrl.join(joinCode: code, displayName: name);
      final sessionId  = entry.key;
      final playersMap = entry.value;

      final isNew = await ctrl.checkNewGame(sessionId);
      final next  = isNew
          ? CreateNewStoryScreen(
        isGroup: true,
        sessionId: sessionId,
        joinCode: code,
        initialPlayersMap: playersMap,
      )
          : MultiplayerHostLobbyScreen(
        sessionId: sessionId,
        joinCode: code,
        initialPlayers: playersMap,
        fromSoloStory: false,
        fromGroupStory: false,
      );

      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => next),
      );
    } catch (e) {
      showError(context, 'Failed to join: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs      = Theme.of(context).colorScheme;
    final tt      = Theme.of(context).textTheme;
    final joining = context.watch<JoinController>().isJoining;

    InputDecoration _dec(String label) => InputDecoration(
      labelText: label,
      border: const OutlineInputBorder(),
    );

    return Scaffold(
      // If you’ve set a pale-yellow scaffold background in your theme
      // this will pick it up automatically; otherwise uncomment the line below.
      // backgroundColor: const Color(0xFFFFFBEA), // extra-pale yellow
      appBar: AppBar(
        backgroundColor: cs.primary,
        centerTitle: true,
        title: Text('Join Game', style: tt.titleLarge),
      ),
      body: Center(                                        // <─ NEW
        child: SingleChildScrollView(                     // <─ NEW
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 320),
                child: TextField(
                  controller: _codeCtrl,
                  decoration: _dec('Join Code'),
                  textAlign: TextAlign.center,
                  textCapitalization: TextCapitalization.characters,
                  onChanged: (v) {
                    final up = v.toUpperCase();
                    if (v != up) {
                      _codeCtrl.value = _codeCtrl.value.copyWith(
                        text: up,
                        selection:
                        TextSelection.collapsed(offset: up.length),
                      );
                    }
                  },
                ),
              ),
              const SizedBox(height: 16),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 320),
                child: TextField(
                  controller: _nameCtrl,
                  decoration: _dec('Your Name'),
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(height: 32),
              ElevatedButton(
                onPressed: joining ? null : _join,
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(200, 48),
                  backgroundColor: cs.primary,
                  foregroundColor: cs.onPrimary,
                ),
                child: joining
                    ? const SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
                    : Text('Join Session', style: tt.labelLarge),
              ),
              const SizedBox(height: 40),
              Image.asset(
                'assets/quill2.png',
                width: 180,
                fit: BoxFit.contain,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
