import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/story_service.dart';
import 'multiplayer_host_lobby_screen.dart';

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
    final joinCode = _codeController.text.trim();
    final displayName = _nameController.text.trim().isEmpty
        ? "Player" // fallback if no name typed
        : _nameController.text.trim();

    if (joinCode.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please enter a join code.")),
      );
      return;
    }

    setState(() => _isJoining = true);
    try {
      // Call the new StoryService method for joining a multiplayer session
      final result = await _storyService.joinMultiplayerSession(
        joinCode: joinCode,
        displayName: displayName,
      );
      /*
        The result from the backend looks like:
        {
          "sessionId": "...",
          "joinCode": "...",
          "storyState": { ... },
          "players": {
            "1": { "userId":"hostId", "displayName":"Host" },
            "2": { "userId":"...", "displayName":"..." },
            ...
          }
        }
      */

      final sessionId = result["sessionId"] as String;
      final storyState = Map<String, dynamic>.from(result["storyState"] ?? {});
      final playersMap = Map<String, dynamic>.from(result["players"] ?? {});

      // Convert the playersMap from <String, dynamic> to a sorted list or keep it as a map
      final Map<int, Map<String, dynamic>> parsedPlayers = playersMap.map(
            (key, val) => MapEntry(int.parse(key), Map<String, dynamic>.from(val)),
      );

      // Now navigate to a lobby screen, passing the data
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => MultiplayerHostLobbyScreen(
            dimensionData: storyState["dimensions"] ?? {},
            sessionId: sessionId,
            joinCode: joinCode,
            playersMap: parsedPlayers,
          ),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Failed to join: $e")),
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
