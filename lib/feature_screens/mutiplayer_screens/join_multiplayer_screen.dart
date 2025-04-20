import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../controllers/join_controller.dart';
import '../../utils/ui_utils.dart';
import '../../services/story_service.dart';
import '../../services/lobby_rtdb_service.dart';
import '../../feature_screens/new_story_screens/create_new_story_screen.dart';
import 'multiplayer_host_lobby_screen.dart';

class JoinMultiplayerScreen extends StatelessWidget {
  const JoinMultiplayerScreen({Key? key}) : super(key: key);

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

class _JoinView extends StatefulWidget {
  const _JoinView({Key? key}) : super(key: key);

  @override
  __JoinViewState createState() => __JoinViewState();
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

  Future<void> _onJoinPressed() async {
    final ctrl = context.read<JoinController>();
    final code = _codeCtrl.text.trim().toUpperCase();
    if (code.isEmpty) {
      showSnack(context, 'Please enter a join code.');
      return;
    }

    final name = _nameCtrl.text.trim().isEmpty
        ? 'Player'
        : _nameCtrl.text.trim();

    try {
      final entry = await ctrl.join(joinCode: code, displayName: name);
      final sessionId = entry.key;
      final playersMap = entry.value;

      final isNew = await ctrl.checkNewGame(sessionId);
      final next = isNew
          ? CreateNewStoryScreen(
        isGroup: true,
        sessionId: sessionId,
        joinCode: code,
        initialPlayersMap: playersMap,
      )
          : MultiplayerHostLobbyScreen(
        sessionId: sessionId,
        joinCode: code,
        playersMap: playersMap,
        fromSoloStory: false,
        fromGroupStory: false,
      );

      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => next),
      );
    } catch (e) {
      showError(context, 'Failed to join: \$e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final isJoining = context.watch<JoinController>().isJoining;

    return Scaffold(
      backgroundColor: const Color(0xFFFFFDE7), // really pale yellow
      appBar: AppBar(
        centerTitle: true,
        title: Text(
          'Join Game',
          style: GoogleFonts.carterOne(),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            const SizedBox(height: 160),
            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 300),
                child: TextField(
                  controller: _codeCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Join Code',
                    labelStyle: TextStyle(color: Colors.black),
                  ),
                  textAlign: TextAlign.center,
                  textCapitalization: TextCapitalization.characters,
                  onChanged: (v) {
                    final up = v.toUpperCase();
                    if (v != up) {
                      _codeCtrl.value = _codeCtrl.value.copyWith(
                        text: up,
                        selection: TextSelection.collapsed(offset: up.length),
                      );
                    }
                  },
                  style: const TextStyle(color: Colors.black),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 300),
                child: TextField(
                  controller: _nameCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Your Name',
                    labelStyle: TextStyle(color: Colors.black),
                  ),
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.black),
                ),
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: isJoining ? null : _onJoinPressed,
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(200, 48),
              ),
              child: isJoining
                  ? const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
                  : Text(
                'Join Session',
                style: GoogleFonts.kottaOne(
                  textStyle: const TextStyle(color: Colors.black),
                ),
              ),
            ),
            const SizedBox(height: 24),
            // Bottom image
            Expanded(
              child: Align(
                alignment: Alignment.bottomCenter,
                child: Image.asset(
                  'assets/quill.png',
                  fit: BoxFit.contain,
                  width: 200,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
