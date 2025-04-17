// lib/screens/multiplayer_host_lobby_screen.dart
// -----------------------------------------------------------------------------
// Host lobby screen using Firebase RTDB service for real‑time updates.
// • Listens to lobby via LobbyRtdbService.lobbyStream
// • Host resolves votes using LobbyRtdbService.resolveVotes()
// • All clients navigate on phase change → 'voteResults'
// • Players can rename themselves via RTDB
// -----------------------------------------------------------------------------

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_database/firebase_database.dart';

import '../services/lobby_rtdb_service.dart';
import 'vote_results_screen.dart';

class MultiplayerHostLobbyScreen extends StatefulWidget {
  final String sessionId;
  final String joinCode;
  final Map<int, Map<String, dynamic>> playersMap;   // initial snapshot

  const MultiplayerHostLobbyScreen({
    Key? key,
    required this.sessionId,
    required this.joinCode,
    required this.playersMap,
  }) : super(key: key);

  @override
  State<MultiplayerHostLobbyScreen> createState() => _MultiplayerHostLobbyScreenState();
}

class _MultiplayerHostLobbyScreenState extends State<MultiplayerHostLobbyScreen> {
  final _lobbySvc = LobbyRtdbService();
  late StreamSubscription _sub;

  late Map<int, Map<String, dynamic>> _playersMap;
  late final String _currentUid;
  bool get _isHost => _playersMap[1]?['userId'] == _currentUid;

  bool _isResolving = false;
  bool _navigated   = false;

  @override
  void initState() {
    super.initState();
    _currentUid = FirebaseAuth.instance.currentUser?.uid ?? '';
    _playersMap = Map.of(widget.playersMap);

    // Subscribe to lobby changes (players, phase, resolvedDimensions)
    _sub = _lobbySvc.lobbyStream(widget.sessionId).listen(_handleLobbySnapshot);
  }

  @override
  void dispose() {
    _sub.cancel();
    super.dispose();
  }

  void _handleLobbySnapshot(DatabaseEvent event) {
    final root = event.snapshot.value as Map<dynamic, dynamic>? ?? {};
    final rawPlayersNode = root['players'];

    // 1) Normalize into a Map<String,dynamic>
    final Map<String, dynamic> flat;
    if (rawPlayersNode is Map) {
      flat = Map<String, dynamic>.from(rawPlayersNode);
    } else if (rawPlayersNode is List) {
      flat = {};
      for (var i = 0; i < rawPlayersNode.length; i++) {
        final e = rawPlayersNode[i];
        if (e is Map) {
          flat['$i'] = Map<String, dynamic>.from(e);
        }
      }
    } else {
      flat = {};
    }

    // 2) Turn that into your int→player map
    final newMap = flat.map<int, Map<String, dynamic>>(
          (k, v) => MapEntry(int.parse(k), Map<String, dynamic>.from(v)),
    );

    // 3) Only setState if it actually changed
    if (newMap.toString() != _playersMap.toString()) {
      setState(() => _playersMap = newMap);
    }

    final phase = root['phase'];
    if (!_navigated && phase == 'voteResults' && root['resolvedDimensions'] != null) {
      final resolvedRaw = root['resolvedDimensions'];
      final resolved = Map<String, String>.from(resolvedRaw is Map ? resolvedRaw : {});
      _goToResults(resolved);
    }

    // 4) Handle phase change as before…
  }

  Future<void> _hostStartStory() async {
    if (!_isHost) return;
    if (_playersMap.length < 2) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Need at least 2 players to start.')),
      );
      return;
    }

    setState(() => _isResolving = true);
    try {
      // Resolve votes → writes phase: 'voteResults' + resolvedDimensions
      await _lobbySvc.resolveVotes(widget.sessionId);
      // _handleLobbySnapshot will pick up phase change and navigate
    } catch (e) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Error resolving votes: $e', style: GoogleFonts.atma())));
    } finally {
      setState(() => _isResolving = false);
    }
  }

  Future<void> _changeMyName() async {
    String tmp = '';
    final newName = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('Change Your Name', style: GoogleFonts.atma()),
        content: TextField(
          autofocus: true,
          onChanged: (v) => tmp = v,
          decoration: const InputDecoration(hintText: 'Enter new display name'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(context, tmp), child: const Text('OK')),
        ],
      ),
    );

    if (newName != null && newName.trim().isNotEmpty) {
      await _lobbySvc.updateMyName(widget.sessionId, newName.trim());
    }
  }

  void _goToResults(Map<String, String> resolved) {
    if (_navigated) return;
    _navigated = true;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => VoteResultsScreen(resolvedResults: resolved, sessionId: widget.sessionId)),
    );
  }

  List<Widget> _playerTiles() {
    final slots = _playersMap.keys.toList()..sort();
    return [
      for (final slot in slots)
        ListTile(
          leading: Text('$slot', style: GoogleFonts.atma(fontSize: 16)),
          title: Text(
            '${_playersMap[slot]!['displayName']}',
            style: GoogleFonts.atma(),
          ),
          trailing: _playersMap[slot]!['userId'] == _currentUid
              ? IconButton(icon: const Icon(Icons.edit), onPressed: _changeMyName)
              : null,
        ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Host Lobby', style: GoogleFonts.atma())),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Join Code:', style: GoogleFonts.atma(fontWeight: FontWeight.bold)),
            SelectableText(widget.joinCode, style: GoogleFonts.atma(fontSize: 24)),
            const SizedBox(height: 16),
            Text('Players in Lobby:', style: GoogleFonts.atma(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Expanded(child: ListView(children: _playerTiles())),
            if (_isHost) ...[
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _isResolving ? null : _hostStartStory,
                child: _isResolving
                    ? const CircularProgressIndicator()
                    : Text('Start Group Story', style: GoogleFonts.atma(fontWeight: FontWeight.bold)),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
