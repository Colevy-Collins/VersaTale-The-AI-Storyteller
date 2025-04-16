// multiplayer_host_lobby_screen.dart

import 'dart:async'; // for Timer
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/story_service.dart';

class MultiplayerHostLobbyScreen extends StatefulWidget {
  final Map<String, dynamic> dimensionData;
  final String sessionId;
  final String joinCode;
  final Map<int, Map<String, dynamic>> playersMap;

  const MultiplayerHostLobbyScreen({
    Key? key,
    required this.dimensionData,
    required this.sessionId,
    required this.joinCode,
    required this.playersMap,
  }) : super(key: key);

  @override
  _MultiplayerHostLobbyScreenState createState() =>
      _MultiplayerHostLobbyScreenState();
}

class _MultiplayerHostLobbyScreenState
    extends State<MultiplayerHostLobbyScreen> {
  late Map<int, Map<String, dynamic>> _playersMap;
  bool _isStartingGame = false;
  final StoryService _storyService = StoryService();

  Timer? _pollTimer;

  @override
  void initState() {
    super.initState();
    _playersMap = Map.of(widget.playersMap);

    // Start polling every few seconds for new players
    _pollTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      _pollForLobbyUpdates();
    });
  }

  @override
  void dispose() {
    // Always cancel the timer to avoid leaks
    _pollTimer?.cancel();
    super.dispose();
  }

  /// Call a backend endpoint to fetch the latest lobby data.
  Future<void> _pollForLobbyUpdates() async {
    try {
      // storyService.fetchLobbyState is a new method you create
      final updatedInfo = await _storyService.fetchLobbyState(widget.sessionId);

      /*
        Suppose updatedInfo might look like:
        {
          "sessionId": "user123-123456789",
          "joinCode": "AB12CD",
          "players": {
            "1": { "userId":"hostId", "displayName":"Alice" },
            "2": { "userId":"player2", "displayName":"Bob" }
          }
        }
      */

      final playersMapRaw = updatedInfo["players"] as Map<String, dynamic>? ?? {};
      final newPlayers = playersMapRaw.map<int, Map<String, dynamic>>(
            (slotStr, pInfo) => MapEntry(
          int.parse(slotStr),
          Map<String, dynamic>.from(pInfo),
        ),
      );

      // Check if something actually changed
      if (_didPlayerListChange(_playersMap, newPlayers)) {
        setState(() {
          _playersMap = newPlayers;
        });
      }
    } catch (e) {
      // If there's an error, you might just ignore or show a debug message
      debugPrint("Polling error: $e");
    }
  }

  /// Simple comparison to see if the map changed
  bool _didPlayerListChange(
      Map<int, Map<String, dynamic>> oldPlayers,
      Map<int, Map<String, dynamic>> newPlayers,
      ) {
    // Quick check: different lengths => changed
    if (oldPlayers.length != newPlayers.length) return true;

    // Check slot by slot
    for (final slot in newPlayers.keys) {
      if (!oldPlayers.containsKey(slot)) return true;
      final old = oldPlayers[slot];
      final now = newPlayers[slot];
      // Compare userId / displayName
      if (old?["userId"] != now?["userId"] ||
          old?["displayName"] != now?["displayName"]) {
        return true;
      }
    }
    return false;
  }

  Future<void> _startGroupStory() async {
    if (_playersMap.length < 2) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Need at least 2 players to start.")),
      );
      return;
    }
    setState(() => _isStartingGame = true);
    await Future.delayed(const Duration(seconds: 1));

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Group story started!")),
    );
    setState(() => _isStartingGame = false);

    Navigator.pop(context);
  }

  List<Widget> _buildPlayerTiles() {
    final slots = _playersMap.keys.toList()..sort();
    return slots.map((slot) {
      final playerData = _playersMap[slot]!;
      final userId = playerData["userId"];
      final displayName = playerData["displayName"];
      return ListTile(
        leading: Text("$slot", style: GoogleFonts.atma(fontSize: 16)),
        title: Text(
          "$displayName ($userId)",
          style: GoogleFonts.atma(fontSize: 16),
        ),
      );
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Host Lobby", style: GoogleFonts.atma()),
        actions: [
          IconButton(
            icon: const Icon(Icons.close),
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              "Share this Join Code with your friends:",
              style: GoogleFonts.atma(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            SelectableText(
              widget.joinCode,
              style: GoogleFonts.atma(fontSize: 24, color: Colors.blue),
            ),
            const SizedBox(height: 24),
            Text("Players in this lobby:",
                style: GoogleFonts.atma(fontSize: 18)),
            const SizedBox(height: 8),
            Expanded(
              child: ListView(
                children: _buildPlayerTiles(),
              ),
            ),
            ElevatedButton(
              onPressed: _isStartingGame ? null : _startGroupStory,
              child: _isStartingGame
                  ? const CircularProgressIndicator()
                  : Text(
                "Start Group Story",
                style: GoogleFonts.atma(fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
