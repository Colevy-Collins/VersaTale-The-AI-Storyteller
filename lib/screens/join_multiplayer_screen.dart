// lib/screens/join_multiplayer_screen.dart
// -----------------------------------------------------------------------------
// Join a multiplayer session using Firebase RTDB.
//  • Validate join code with backend.
//  • Register player in RTDB so everyone sees the new lobby entry.
//  • Navigate into CreateNewStoryScreen (joiner/vote UI).
// -----------------------------------------------------------------------------

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../services/story_service.dart';
import '../services/lobby_rtdb_service.dart';
import 'create_new_story_screen.dart';
import 'multiplayer_host_lobby_screen.dart';

class JoinMultiplayerScreen extends StatefulWidget {
  const JoinMultiplayerScreen({Key? key}) : super(key: key);

  @override
  State<JoinMultiplayerScreen> createState() => _JoinMultiplayerScreenState();
}

class _JoinMultiplayerScreenState extends State<JoinMultiplayerScreen> {
  final _codeCtrl = TextEditingController();
  final _nameCtrl = TextEditingController();
  final _storySvc = StoryService();
  final _lobbySvc = LobbyRtdbService();

  bool _joining = false;

  @override
  void dispose() {
    _codeCtrl.dispose();
    _nameCtrl.dispose();
    super.dispose();
  }

  Future<void> _joinSession() async {
    final joinCode = _codeCtrl.text.trim().toUpperCase();
    final displayName = _nameCtrl.text.trim().isEmpty
        ? 'Player'
        : _nameCtrl.text.trim();

    if (joinCode.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a join code.')),
      );
      return;
    }

    setState(() => _joining = true);
    try {
      // 1️⃣ Validate join code and fetch sessionId
      final res = await _storySvc.joinMultiplayerSession(
        joinCode: joinCode,
        displayName: displayName,
      );

      final sessionId = res['sessionId'] as String;

      // 2️⃣ RTDB: register this player so lobby updates for everyone
      await _lobbySvc.joinSession(
        sessionId: sessionId,
        displayName: displayName,
      );

      final playersRaw  = Map<String, dynamic>.from(res['players'] ?? {});
      final playersMap  = playersRaw.map<int, Map<String, dynamic>>(
            (k, v) => MapEntry(int.parse(k), Map<String, dynamic>.from(v)),
      );

      // 3️⃣ Navigate into the voting screen
      if (!mounted) return;
      bool isNewStory = await _lobbySvc.checkDefaultDims(sessionId: sessionId);
      if(isNewStory){

        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => CreateNewStoryScreen(
              isGroup: true,
              sessionId: sessionId,
              joinCode: joinCode,
              initialPlayersMap: playersMap,
            ),
          ),
        );
      } else {

        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => MultiplayerHostLobbyScreen(
              sessionId:  sessionId,
              joinCode:   joinCode,
              playersMap: playersMap,
              fromSoloStory: false,
              fromGroupStory: false,
            ),
          ),
        );

      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to join: $e', style: GoogleFonts.atma())),
      );
    } finally {
      setState(() => _joining = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Join Game', style: GoogleFonts.atma()),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(
              controller: _codeCtrl,
              decoration: const InputDecoration(labelText: 'Join Code'),
              textCapitalization: TextCapitalization.characters,
              onChanged: (v) {
                final upper = v.toUpperCase();
                if (_codeCtrl.text != upper) {
                  _codeCtrl.value = _codeCtrl.value.copyWith(
                    text: upper,
                    selection: TextSelection.collapsed(offset: upper.length),
                  );
                }
              },
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _nameCtrl,
              decoration: const InputDecoration(labelText: 'Your Name'),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _joining ? null : _joinSession,
              child: _joining
                  ? const CircularProgressIndicator()
                  : Text('Join Session', style: GoogleFonts.atma()),
            ),
          ],
        ),
      ),
    );
  }
}
