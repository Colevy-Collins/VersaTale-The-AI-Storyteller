// lib/screens/multiplayer_host_lobby_screen.dart

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/story_service.dart';
import '../services/auth_service.dart';
import 'vote_results_screen.dart';

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
  bool _isResolving = false;
  bool _hasResolved = false;
  late String _currentUserId;
  Timer? _pollTimer;

  final StoryService _storyService = StoryService();
  final AuthService _authService = AuthService();

  bool get _isHost => _playersMap[1]?['userId'] == _currentUserId;

  @override
  void initState() {
    super.initState();
    _currentUserId = _authService.getCurrentUser()?.uid ?? '';
    _playersMap = Map.of(widget.playersMap);
    _pollTimer = Timer.periodic(const Duration(seconds: 3), (_) {
      _pollForLobbyUpdates();
    });
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }

  Future<void> _pollForLobbyUpdates() async {
    try {
      final updated = await _storyService.fetchLobbyState(widget.sessionId);

      // If server has resolved votes, navigate everyone once:
      if (!_hasResolved && updated.containsKey('resolvedDimensions')) {
        _hasResolved = true;
        final resolved = Map<String, String>.from(updated['resolvedDimensions']);
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => VoteResultsScreen(
              resolvedResults: resolved,  // <-- fixed
            ),
          ),
        );
        return;
      }

      // Otherwise update the players list
      final rawPlayers = updated['players'] as Map<String, dynamic>? ?? {};
      final newMap = rawPlayers.map<int, Map<String, dynamic>>(
            (k, v) => MapEntry(int.parse(k), Map<String, dynamic>.from(v)),
      );
      if (_didPlayerListChange(_playersMap, newMap)) {
        setState(() => _playersMap = newMap);
      }
    } catch (e) {
      debugPrint('Polling error: $e');
    }
  }

  bool _didPlayerListChange(
      Map<int, Map<String, dynamic>> oldP,
      Map<int, Map<String, dynamic>> newP,
      ) {
    if (oldP.length != newP.length) return true;
    for (final slot in newP.keys) {
      final o = oldP[slot], n = newP[slot];
      if (o == null ||
          o['userId'] != n?['userId'] ||
          o['displayName'] != n?['displayName']) {
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
    setState(() => _isResolving = true);

    try {
      final result = await _storyService.resolveVotes(widget.sessionId);
      final resolved = Map<String, String>.from(result['resolvedDimensions']);

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => VoteResultsScreen(
            resolvedResults: resolved,  // <-- fixed
          ),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Failed to start: $e")),
      );
    } finally {
      setState(() => _isResolving = false);
    }
  }

  Future<String?> _showChangeNameDialog() {
    String tmp = '';
    return showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text("Change Your Name", style: GoogleFonts.atma()),
        content: TextField(
          autofocus: true,
          onChanged: (v) => tmp = v,
          decoration: const InputDecoration(hintText: "New display name"),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
          TextButton(onPressed: () => Navigator.pop(context, tmp), child: const Text("OK")),
        ],
      ),
    );
  }

  Future<void> _updateMyName(String newName) async {
    try {
      await _storyService.updatePlayerName({'newDisplayName': newName});
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Name updated.")),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error: $e")),
      );
    }
  }

  List<Widget> _buildPlayerTiles() {
    final slots = _playersMap.keys.toList()..sort();
    return slots.map((s) {
      final p = _playersMap[s]!;
      return ListTile(
        leading: Text("$s", style: GoogleFonts.atma(fontSize: 16)),
        title: Text("${p['displayName']} (${p['userId']})", style: GoogleFonts.atma()),
        trailing: p['userId'] == _currentUserId
            ? IconButton(
          icon: const Icon(Icons.edit),
          onPressed: () async {
            final n = await _showChangeNameDialog();
            if (n != null && n.trim().isNotEmpty) {
              await _updateMyName(n.trim());
            }
          },
        )
            : null,
      );
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Host Lobby", style: GoogleFonts.atma()),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text("Join Code:", style: GoogleFonts.atma(fontWeight: FontWeight.bold)),
            SelectableText(widget.joinCode, style: GoogleFonts.atma(fontSize: 24)),
            const SizedBox(height: 16),
            Text("Players in Lobby:", style: GoogleFonts.atma(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Expanded(child: ListView(children: _buildPlayerTiles())),
            if (_isHost) ...[
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _isResolving ? null : _startGroupStory,
                child: _isResolving
                    ? const CircularProgressIndicator()
                    : Text("Start Group Story", style: GoogleFonts.atma(fontWeight: FontWeight.bold)),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
