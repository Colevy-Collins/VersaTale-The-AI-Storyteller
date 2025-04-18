// lib/screens/multiplayer_host_lobby_screen.dart
// -----------------------------------------------------------------------------
// Host lobby screen using Firebase RTDB service for real‑time updates.
// • Listens to lobby via LobbyRtdbService.lobbyStream
// • Host resolves votes via LobbyRtdbService.resolveVotes()
// • Solo host flips phase→'story' + payload
// • All clients navigate on phase change → 'voteResults' or 'story'
// • Players can rename themselves via RTDB
// -----------------------------------------------------------------------------

import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_database/firebase_database.dart';

import '../services/lobby_rtdb_service.dart';
import 'vote_results_screen.dart';
import 'story_screen.dart';

class MultiplayerHostLobbyScreen extends StatefulWidget {
  final String sessionId;
  final String joinCode;
  final Map<int, Map<String, dynamic>> playersMap;
  final bool fromSoloStory;
  final bool fromGroupStory;

  /// When coming from a solo story, pass in your storyPayload here:
  /// {
  ///   'initialLeg': ...,
  ///   'options': [...],
  ///   'storyTitle': ...,
  /// }

  const MultiplayerHostLobbyScreen({
    Key? key,
    required this.sessionId,
    required this.joinCode,
    required this.playersMap,
    this.fromSoloStory = false,
    this.fromGroupStory = false,
  }) : super(key: key);

  @override
  State<MultiplayerHostLobbyScreen> createState() =>
      _MultiplayerHostLobbyScreenState();
}

class _MultiplayerHostLobbyScreenState
    extends State<MultiplayerHostLobbyScreen> {
  final _lobbySvc = LobbyRtdbService();
  late StreamSubscription<DatabaseEvent> _sub;
  late Map<int, Map<String, dynamic>> _playersMap;
  late final String _currentUid;
  bool get _isHost => _playersMap[1]?['userId'] == _currentUid;

  bool _isResolving = false;
  bool _navigated     = false;
  String? _lastPhase;     // track last seen RTDB phase

  @override
  void initState() {
    super.initState();
    _currentUid = FirebaseAuth.instance.currentUser?.uid ?? '';
    _playersMap = Map.of(widget.playersMap);
    _lastPhase  = null;

    // Start listening for phase changes + player updates
    _sub = _lobbySvc
        .lobbyStream(widget.sessionId)
        .listen(_handleLobbySnapshot);
  }

  @override
  void dispose() {
    _sub.cancel();
    super.dispose();
  }

  void _handleLobbySnapshot(DatabaseEvent event) {
    final root = event.snapshot.value as Map<dynamic, dynamic>? ?? {};
    // — normalize players…
    final rawPlayers = root['players'];
    final flat = <String, dynamic>{};
    if (rawPlayers is Map) {
      flat.addAll(Map<String, dynamic>.from(rawPlayers));
    } else if (rawPlayers is List) {
      for (var i = 0; i < rawPlayers.length; i++) {
        final e = rawPlayers[i];
        if (e is Map) flat['$i'] = Map<String, dynamic>.from(e);
      }
    }
    final newMap = flat.map<int, Map<String, dynamic>>(
          (k, v) => MapEntry(int.parse(k), Map<String, dynamic>.from(v)),
    );
    if (newMap.toString() != _playersMap.toString()) {
      setState(() => _playersMap = newMap);
    }

    // — determine phase transitions only
    final newPhase = (root['phase'] as String?) ?? 'lobby';

    // first snapshot: just record it
    if (_lastPhase == null) {
      _lastPhase = newPhase;
      return;
    }

    // if phase truly changed
    if (!_navigated && newPhase != _lastPhase) {
      if (newPhase == 'voteResults' && root['resolvedDimensions'] != null) {
        final resolvedRaw = root['resolvedDimensions'];
        final resolved = Map<String, String>.from(
          resolvedRaw is Map ? resolvedRaw : {},
        );
        _goToResults(resolved);

      } else if (newPhase == 'story' && root['storyPayload'] != null) {
        _goToStoryScreen();
      }
    }

    _lastPhase = newPhase;
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
      await _lobbySvc.resolveVotes(widget.sessionId);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content:
          Text('Error resolving votes: $e', style: GoogleFonts.atma()),
        ),
      );
    } finally {
      setState(() => _isResolving = false);
    }
  }

  Future<void> _changeMyName() async {
    var tmp = '';
    final newName = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('Change Your Name', style: GoogleFonts.atma()),
        content: TextField(
          autofocus: true,
          onChanged: (v) => tmp = v,
          decoration:
          const InputDecoration(hintText: 'Enter new display name'),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.pop(context, tmp),
              child: const Text('OK')),
        ],
      ),
    );
    if (newName != null && newName.trim().isNotEmpty) {
      await _lobbySvc.updateMyName(
          widget.sessionId, newName.trim());
    }
  }

  Future<void> _goToStoryScreen() async {
    if (_navigated) return;
    _navigated = true;

    setState(() => _isResolving = true);
    final payload = await _lobbySvc
        .fetchStoryPayloadIfInStoryPhase(sessionId: widget.sessionId);

    if (payload == null) {
      // nothing to show – reset spinner & allow retry
      _navigated = false;
      setState(() => _isResolving = false);
      return;
    }
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => StoryScreen(
          sessionId:  widget.sessionId,
          initialLeg: payload['initialLeg'],
          options:    List<String>.from(payload['options'] ?? []),
          storyTitle: payload['storyTitle'],
          joinCode:  widget.joinCode,
        ),
      ),
    );
  }

  /// **Solo** host: flip phase → 'story' **and** push payload in one atomic write.
  Future<void> _goToStoryScreenFromSolo() async {
    if (!_isHost || _navigated) return;

    setState(() => _isResolving = true);
    try {
      // WRITE both phase *and* payload in one update:
      await FirebaseDatabase.instance
          .ref('lobbies/${widget.sessionId}')
          .update({
        'phase':        'story',
      });
      // after this, our listener will see the phase change & navigate everyone
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content:
          Text('Error starting solo story: $e', style: GoogleFonts.atma()),
        ),
      );
      setState(() => _isResolving = false);
    }
  }

  void _goToResults(Map<String, String> resolved) {
    if (_navigated) return;
    _navigated = true;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => VoteResultsScreen(
          resolvedResults: resolved,
          sessionId:       widget.sessionId,
          joinCode:        widget.joinCode,
        ),
      ),
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
              ? IconButton(
            icon: const Icon(Icons.edit),
            onPressed: _changeMyName,
          )
              : null,
        ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar:
      AppBar(title: Text('Host Lobby', style: GoogleFonts.atma())),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Join Code:',
                style: GoogleFonts.atma(fontWeight: FontWeight.bold)),
            SelectableText(widget.joinCode,
                style: GoogleFonts.atma(fontSize: 24)),
            const SizedBox(height: 16),
            Text('Players in Lobby:',
                style: GoogleFonts.atma(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Expanded(child: ListView(children: _playerTiles())),

            // — group story start
            if (_isHost &&
                !widget.fromSoloStory &&
                !widget.fromGroupStory) ...[
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _isResolving ? null : _hostStartStory,
                child: _isResolving
                    ? const CircularProgressIndicator()
                    : Text('Start Group Story',
                    style: GoogleFonts.atma(
                        fontWeight: FontWeight.bold)),
              ),
            ],

            // — solo story start
            if (_isHost && widget.fromSoloStory) ...[
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed:
                _isResolving ? null : _goToStoryScreenFromSolo,
                child: _isResolving
                    ? const CircularProgressIndicator()
                    : Text('Go To Story',
                    style: GoogleFonts.atma(
                        fontWeight: FontWeight.bold)),
              ),
            ],
            if (widget.fromGroupStory) ...[
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed:
                _isResolving ? null : _goToStoryScreen,
                child: _isResolving
                    ? const CircularProgressIndicator()
                    : Text('Go To Story',
                    style: GoogleFonts.atma(
                        fontWeight: FontWeight.bold)),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
