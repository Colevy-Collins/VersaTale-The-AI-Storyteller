import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/story_service.dart';
import '../services/auth_service.dart';
import 'vote_results_screen.dart';

class MultiplayerHostLobbyScreen extends StatefulWidget {
  final Map<String, dynamic> dimensionData;      // not used here now
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
  final StoryService  _storyService = StoryService();
  final AuthService   _authService  = AuthService();

  late final String _currentUserId;
  Timer? _pollTimer;
  bool _isResolving = false;
  bool _hasNavigatedToResults = false;

  bool get _isHost => _playersMap[1]?['userId'] == _currentUserId;

  @override
  void initState() {
    super.initState();
    _currentUserId = _authService.getCurrentUser()?.uid ?? '';
    _playersMap = Map.of(widget.playersMap);

    _pollTimer = Timer.periodic(const Duration(seconds: 3), (_) {
      _pollLobby();
    });
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }

  /* ---------------------------------- polling ---------------------------------- */

  Future<void> _pollLobby() async {
    try {
      final data = await _storyService.fetchLobbyState(widget.sessionId);

      /* 1. Vote resolution */
      if (data['votesResolved'] == true && !_hasNavigatedToResults) {
        _hasNavigatedToResults = true;
        final resolved = Map<String, String>.from(data['resolvedDimensions']);
        _goToResults(resolved);
        return; // stop further handling in this tick
      }

      /* 2. Player list update */
      final rawPlayers = data['players'] as Map<String, dynamic>? ?? {};
      final newMap = rawPlayers.map<int, Map<String, dynamic>>(
            (k, v) => MapEntry(int.parse(k), Map<String, dynamic>.from(v)),
      );
      if (_playersChanged(_playersMap, newMap)) {
        setState(() => _playersMap = newMap);
      }
    } catch (e) {
      debugPrint('Lobby polling error: $e');
    }
  }

  bool _playersChanged(
      Map<int, Map<String, dynamic>> oldP,
      Map<int, Map<String, dynamic>> newP) {
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

  /* ---------------------------- host: resolve votes ---------------------------- */

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
      final resolved =
      Map<String, String>.from(result['resolvedDimensions']);
      _goToResults(resolved);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Failed to start: $e")),
      );
    } finally {
      setState(() => _isResolving = false);
    }
  }

  void _goToResults(Map<String, String> resolved) {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => VoteResultsScreen(resolvedResults: resolved),
      ),
    );
  }

  /* ------------------------------ name change UI ------------------------------ */

  Future<void> _updateMyName(String newName) async {
    try {
      await _storyService.updatePlayerName({'newDisplayName': newName});
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text("Name updated.")));
    } catch (e) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text("Error: $e")));
    }
  }

  Future<String?> _askForName() {
    String tmp = '';
    return showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text("Change Your Name", style: GoogleFonts.atma()),
        content: TextField(
          autofocus: true,
          onChanged: (v) => tmp = v,
          decoration:
          const InputDecoration(hintText: "Enter new display name"),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
          TextButton(onPressed: () => Navigator.pop(context, tmp), child: const Text("OK")),
        ],
      ),
    );
  }

  /* --------------------------------- UI build --------------------------------- */

  List<Widget> _playerTiles() {
    final slots = _playersMap.keys.toList()..sort();
    return [
      for (final s in slots)
        ListTile(
          leading: Text("$s", style: GoogleFonts.atma(fontSize: 16)),
          title: Text(
            "${_playersMap[s]!['displayName']} (${_playersMap[s]!['userId']})",
            style: GoogleFonts.atma(),
          ),
          trailing: _playersMap[s]!['userId'] == _currentUserId
              ? IconButton(
            icon: const Icon(Icons.edit),
            onPressed: () async {
              final n = await _askForName();
              if (n != null && n.trim().isNotEmpty) {
                await _updateMyName(n.trim());
              }
            },
          )
              : null,
        )
    ];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Host Lobby", style: GoogleFonts.atma())),
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
            Expanded(child: ListView(children: _playerTiles())),
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
