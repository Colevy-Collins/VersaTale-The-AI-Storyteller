// lib/screens/vote_results_screen.dart
// -----------------------------------------------------------------------------
// After voting on dimensions, this screen shows the resolved winners.
// When the host presses “Continue to Story” we request the first leg from the
// backend, then broadcast a `storyPayload` that contains:
//   • initialLeg / options / storyTitle
//   • inputTokens / outputTokens / estimatedCostUsd  ← NEW
// All participants listen for phase == 'story' and auto-navigate.
// -----------------------------------------------------------------------------

import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../services/lobby_rtdb_service.dart';
import '../../services/story_service.dart';
import '../../services/dimension_exclusions.dart';
import '../../utils/lobby_utils.dart';
import '../../utils/ui_utils.dart';
import '../story_screen.dart';

class VoteResultsScreen extends StatefulWidget {
  const VoteResultsScreen({
    Key? key,
    required this.sessionId,
    required this.resolvedResults,
    required this.joinCode,
  }) : super(key: key);

  final String sessionId;
  final Map<String, String> resolvedResults;
  final String joinCode;

  @override
  State<VoteResultsScreen> createState() => _VoteResultsScreenState();
}

/* ────────────────────────────────────────────────────────────────────────── */

class _VoteResultsScreenState extends State<VoteResultsScreen> {
  // services
  final _lobbyService = LobbyRtdbService();
  final _storyService = StoryService();

  late final String _currentUid;
  late final StreamSubscription _lobbySub;

  bool _isHost  = false;
  bool _loading = false; // continue button spinner

  @override
  void initState() {
    super.initState();
    _currentUid = FirebaseAuth.instance.currentUser!.uid;

    // listen to lobby changes
    _lobbySub = _lobbyService
        .lobbyStream(widget.sessionId)
        .listen(_handleLobbyUpdate);
  }

  @override
  void dispose() {
    _lobbySub.cancel();
    super.dispose();
  }

  /* ───────────────────────── Lobby Handlers ───────────────────────────── */

  void _handleLobbyUpdate(DatabaseEvent event) {
    final root = Map<dynamic, dynamic>.from(event.snapshot.value as Map? ?? {});
    _updateHostStatus(root);
    _maybeNavigateToStory(root);
  }

  void _updateHostStatus(Map<dynamic, dynamic> root) {
    bool newHost;
    final hostUid = root['hostUid'] as String?;
    if (hostUid != null) {
      newHost = hostUid == _currentUid;
    } else {
      final players = LobbyUtils.normalizePlayers(root['players']);
      newHost = (players['1'] as Map?)?['userId'] == _currentUid;
    }
    if (mounted && newHost != _isHost) setState(() => _isHost = newHost);
  }

  void _maybeNavigateToStory(Map<dynamic, dynamic> root) {
    if (root['phase'] == 'story' && root['storyPayload'] != null) {
      _navigateToStoryScreen(
          Map<String, dynamic>.from(root['storyPayload']));
    }
  }

  /* ───────────────────────── Navigation ──────────────────────────────── */

  void _navigateToStoryScreen(Map<String, dynamic> payload) {
    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => StoryScreen(
          sessionId : widget.sessionId,
          joinCode  : widget.joinCode,
          initialLeg: payload['initialLeg'] as String,
          options   : List<String>.from(payload['options'] as List),
          storyTitle: payload['storyTitle'] as String,
          // seed usage counters so badge is correct on first frame
          inputTokens     : payload['inputTokens']     ?? 0,
          outputTokens    : payload['outputTokens']    ?? 0,
          estimatedCostUsd: payload['estimatedCostUsd']?? 0.0,
        ),
      ),
    );
  }

  /* ───────────────────── Host “Continue” Button ─────────────────────── */

  Future<void> _onContinuePressed() async {
    setState(() => _loading = true);
    try {
      // 1) Ask backend for the first leg
      final res = await _storyService.startStory(
        decision     : 'Start Story',
        dimensionData: widget.resolvedResults,
        maxLegs      : 10,
        optionCount  : 2,
        storyLength  : 'Short',
      );

      // 2) Broadcast to RTDB (includes counters)
      await _lobbyService.advanceToStoryPhase(
        sessionId: widget.sessionId,
        storyPayload: {
          'initialLeg'      : res['storyLeg'],
          'options'         : List<String>.from(res['options'] ?? []),
          'storyTitle'      : res['storyTitle'],
          'inputTokens'     : res['inputTokens'],
          'outputTokens'    : res['outputTokens'],
          'estimatedCostUsd': res['estimatedCostUsd'],
        },
      );
    } catch (e) {
      showError(context, 'Error starting story: $e');
      setState(() => _loading = false);
    }
  }

  /* ─────────────────────────── UI Build ─────────────────────────────── */

  @override
  Widget build(BuildContext context) {
    final visibleDims = widget.resolvedResults.keys
        .where((k) => !excludedDimensions.contains(k))
        .toList()
      ..sort();

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: Text('Vote Results', style: GoogleFonts.atma()),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: ListView.separated(
          itemCount: visibleDims.length,
          separatorBuilder: (_, __) => const SizedBox(height: 8),
          itemBuilder: (_, idx) {
            final dim = visibleDims[idx];
            return Card(
              elevation: 2,
              child: ListTile(
                title   : Text(dim, style: GoogleFonts.atma(fontWeight: FontWeight.bold)),
                subtitle: Text(widget.resolvedResults[dim]!, style: GoogleFonts.atma()),
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
          'Waiting for host to start story…',
          textAlign: TextAlign.center,
          style: GoogleFonts.atma(fontSize: 16),
        ),
      ),
    );
  }
}
