import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/story_service.dart';
import 'create_new_story_screen.dart';

class JoinMultiplayerScreen extends StatefulWidget {
  const JoinMultiplayerScreen({Key? key}) : super(key: key);

  @override
  _JoinMultiplayerScreenState createState() => _JoinMultiplayerScreenState();
}

class _JoinMultiplayerScreenState extends State<JoinMultiplayerScreen> {
  final TextEditingController _codeController = TextEditingController();
  final TextEditingController _nameController = TextEditingController();
  bool _isJoining = false;
  final StoryService _storyService = StoryService();

  Future<void> _joinSession() async {
    final joinCode = _codeController.text.trim().toUpperCase();
    final displayName = _nameController.text.trim().isEmpty
        ? "Player"
        : _nameController.text.trim();

    if (joinCode.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please enter a join code.")),
      );
      return;
    }

    setState(() => _isJoining = true);
    try {
      final result = await _storyService.joinMultiplayerSession(
        joinCode: joinCode,
        displayName: displayName,
      );

      final sessionId = result["sessionId"] as String;
      final storyState = Map<String, dynamic>.from(result["storyState"] ?? {});
      final playersMapRaw = Map<String, dynamic>.from(result["players"] ?? {});
      final parsedPlayers = playersMapRaw.map<int, Map<String, dynamic>>(
            (slotStr, info) => MapEntry(
          int.parse(slotStr),
          Map<String, dynamic>.from(info),
        ),
      );

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => CreateNewStoryScreen(
            isGroup: true,
            sessionId: sessionId,
            joinCode: joinCode,
            initialPlayersMap: parsedPlayers,
          ),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Failed to join: \$e")),
      );
    } finally {
      setState(() => _isJoining = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Join Game", style: GoogleFonts.atma()),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(
              controller: _codeController,
              decoration: const InputDecoration(labelText: "Join Code"),
              onChanged: (value) {
                final upperValue = value.toUpperCase();
                if (_codeController.text != upperValue) {
                  _codeController.value = _codeController.value.copyWith(
                    text: upperValue,
                    selection: TextSelection.collapsed(offset: upperValue.length),
                  );
                }
              },
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(labelText: "Your Name"),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _isJoining ? null : _joinSession,
              child: _isJoining
                  ? const CircularProgressIndicator()
                  : Text("Join Session", style: GoogleFonts.atma()),
            ),
          ],
        ),
      ),
    );
  }
}

