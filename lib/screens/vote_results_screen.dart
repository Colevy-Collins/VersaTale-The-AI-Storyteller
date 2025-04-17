// lib/screens/vote_results_screen.dart
// -----------------------------------------------------------------------------
// Shows resolved dimensions after voting and transitions to story phase via RTDB.
// • Listens on RTDB phase == 'story' to auto-navigate joiners
// • Host-only 'Continue to Story' button triggers story generation
// -----------------------------------------------------------------------------

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_database/firebase_database.dart';

import '../services/lobby_rtdb_service.dart';
import '../services/story_service.dart';
import '../services/dimension_exclusions.dart';
import 'story_screen.dart';

class VoteResultsScreen extends StatefulWidget {
  final String sessionId;
  final Map<String, String> resolvedResults;

  const VoteResultsScreen({
    Key? key,
    required this.sessionId,
    required this.resolvedResults,
  }) : super(key: key);

  @override
  _VoteResultsScreenState createState() => _VoteResultsScreenState();
}

class _VoteResultsScreenState extends State<VoteResultsScreen> {
  final _lobbySvc = LobbyRtdbService();
  final _storySvc = StoryService();

  late StreamSubscription _sub;
  late final String _currentUid;
  bool _isHost = false;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _currentUid = FirebaseAuth.instance.currentUser?.uid ?? '';

    // Listen for phase == 'story' and navigate
    _sub = _lobbySvc.lobbyStream(widget.sessionId).listen(_onLobbyUpdate);
  }

  @override
  void dispose() {
    _sub.cancel();
    super.dispose();
  }

  void _onLobbyUpdate(DatabaseEvent event) {
    final root = event.snapshot.value as Map<dynamic, dynamic>? ?? {};

    /* ── 1. Who is the host? ─────────────────────────────────────────────── */
    bool newIsHost = false;
    final rawPlayers = root['players'];
    Map<String, dynamic> players = {};

    if (rawPlayers is Map) {
      players = Map<String, dynamic>.from(rawPlayers);
    } else if (rawPlayers is List) {
      for (var i = 0; i < rawPlayers.length; i++) {
        final entry = rawPlayers[i];
        if (entry is Map) players['$i'] = entry;
      }
    }

    final hostInfo = players['1'] as Map?;
    if (hostInfo != null) {
      newIsHost = (hostInfo['userId'] == _currentUid);
    }

    if (newIsHost != _isHost && mounted) {
      setState(() => _isHost = newIsHost);   // ← UI refresh
    }

    /* ── 2. Auto‑navigate when the story is ready ────────────────────────── */
    if (root['phase'] == 'story' && root['storyPayload'] != null) {
      final payload = Map<String, dynamic>.from(root['storyPayload']);
      _navigateToStoryScreen(payload);
    }
  }
  void _navigateToStoryScreen(Map<String, dynamic> payload) {
    // Prevent duplicate navigation
    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => StoryScreen(
          initialLeg: payload['initialLeg'] as String,
          options: List<String>.from(payload['options'] as List<dynamic>),
          storyTitle: payload['storyTitle'] as String,
        ),
      ),
    );
  }

  Future<void> _onContinuePressed() async {
    setState(() => _loading = true);
    try {
      // Generate first story leg via backend
      final res = await _storySvc.startStory(
        decision: 'Start Story',
        dimensionData: widget.resolvedResults,
        maxLegs: 10,             // or retrieve from initial config
        optionCount: 2,          // adjust as needed
        storyLength: 'Short',    // adjust as needed
      );

      // Broadcast via RTDB
      await _lobbySvc.advanceToStoryPhase(
        sessionId: widget.sessionId,
        storyPayload: {
          'initialLeg': res['storyLeg'],
          'options': List<String>.from(res['options'] ?? []),
          'storyTitle': res['storyTitle'],
        },
      );
      // joiners and host will auto-navigate in _onLobbyUpdate
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error starting story: $e', style: GoogleFonts.atma())),
      );
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final visibleDims = widget.resolvedResults.keys
        .where((k) => !excludedDimensions.contains(k))
        .toList()
      ..sort();

    return Scaffold(
      appBar: AppBar(
        title: Text('Vote Results', style: GoogleFonts.atma()),
        automaticallyImplyLeading: false,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: ListView.separated(
          itemCount: visibleDims.length,
          separatorBuilder: (_, __) => const SizedBox(height: 8),
          itemBuilder: (context, idx) {
            final key = visibleDims[idx];
            return Card(
              elevation: 2,
              child: ListTile(
                title: Text(key, style: GoogleFonts.atma(fontWeight: FontWeight.bold)),
                subtitle: Text(widget.resolvedResults[key]!, style: GoogleFonts.atma()),
              ),
            );
          },
        ),
      ),
      bottomNavigationBar: Padding(
        padding: const EdgeInsets.all(16),
        child: _isHost
            ? ElevatedButton(
          onPressed: _loading ? null : _onContinuePressed,
          style: ElevatedButton.styleFrom(minimumSize: const Size.fromHeight(48)),
          child: _loading
              ? const CircularProgressIndicator()
              : Text('Continue to Story', style: GoogleFonts.atma()),
        )
            : Text(
          'Waiting for host to start story...',
          textAlign: TextAlign.center,
          style: GoogleFonts.atma(fontSize: 16),
        ),
      ),
    );
  }
}
