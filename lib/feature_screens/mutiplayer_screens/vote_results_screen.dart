// After voting, host sees winners and can continue to story.
import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';

import '../../services/lobby_rtdb_service.dart';
import '../../services/story_service.dart';
import '../../services/dimension_exclusions.dart';
import '../../utils/lobby_utils.dart';
import '../../utils/ui_utils.dart';
import '../story_screen.dart';

class VoteResultsScreen extends StatefulWidget {
  const VoteResultsScreen({
    super.key,
    required this.sessionId,
    required this.resolvedResults,
    required this.joinCode,
  });

  final String sessionId;
  final Map<String, String> resolvedResults;
  final String joinCode;

  @override
  State<VoteResultsScreen> createState() => _VoteResultsScreenState();
}

/* ───────────────────────────────────────────────────────────────────── */

class _VoteResultsScreenState extends State<VoteResultsScreen> {
  final _lobbySvc = LobbyRtdbService();
  final _storySvc = StoryService();

  late final String _uid;
  late final StreamSubscription _sub;

  bool _isHost = false;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _uid = FirebaseAuth.instance.currentUser!.uid;
    _sub = _lobbySvc.lobbyStream(widget.sessionId).listen(_onLobby);
  }

  @override
  void dispose() {
    _sub.cancel();
    super.dispose();
  }

  /* ───────── lobby handlers ───────── */

  void _onLobby(DatabaseEvent e) {
    final root = Map<dynamic, dynamic>.from(e.snapshot.value as Map? ?? {});
    _updateHost(root);
    _maybeNavigateToStory(root);
  }

  void _updateHost(Map root) {
    final hostUid = root['hostUid'] as String?;
    final players = LobbyUtils.normalizePlayers(root['players']);
    final isHost = (hostUid ?? (players['1']?['userId'])) == _uid;
    if (mounted && isHost != _isHost) setState(() => _isHost = isHost);
  }

  void _maybeNavigateToStory(Map root) {
    if (root['phase'] == 'story' && root['storyPayload'] != null) {
      _goToStory(Map<String, dynamic>.from(root['storyPayload']));
    }
  }

  /* ───────── navigation ───────── */

  void _goToStory(Map payload) {
    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => StoryScreen(
          sessionId: widget.sessionId,
          joinCode: widget.joinCode,
          initialLeg: payload['initialLeg'],
          options: List<String>.from(payload['options'] ?? []),
          storyTitle: payload['storyTitle'],
          inputTokens: payload['inputTokens'] ?? 0,
          outputTokens: payload['outputTokens'] ?? 0,
          estimatedCostUsd: payload['estimatedCostUsd'] ?? 0.0,
        ),
      ),
    );
  }

  /* ───────── host “continue” ───────── */

  Future<void> _continue() async {
    setState(() => _loading = true);
    try {
      final res = await _storySvc.startStory(
        decision: 'Start Story',
        dimensionData: widget.resolvedResults,
      );

      await _lobbySvc.advanceToStoryPhase(
        sessionId: widget.sessionId,
        storyPayload: {
          'initialLeg': res['storyLeg'],
          'options': List<String>.from(res['options'] ?? []),
          'storyTitle': res['storyTitle'],
          'inputTokens': res['inputTokens'],
          'outputTokens': res['outputTokens'],
          'estimatedCostUsd': res['estimatedCostUsd'],
        },
      );
    } catch (e) {
      showError(context, 'Error starting story: $e');
      setState(() => _loading = false);
    }
  }

  /* ───────── UI ───────── */

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    //.where((k) => !excludedDimensions.contains(k))
    final dims = widget.resolvedResults.keys
        .toList()
      ..sort();

    return Scaffold(
      appBar: AppBar(
        title: Text('Vote Results', style: tt.titleLarge),
        backgroundColor: cs.primary,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: ListView.separated(
          itemCount: dims.length,
          separatorBuilder: (_, __) => const SizedBox(height: 8),
          itemBuilder: (_, i) {
            final dim = dims[i];
            return Card(
              child: ListTile(
                title: Text(dim,
                    style: tt.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                subtitle: Text(widget.resolvedResults[dim]!, style: tt.bodyMedium),
              ),
            );
          },
        ),
      ),
      bottomNavigationBar: Padding(
        padding: const EdgeInsets.all(16),
        child: _isHost
            ? ElevatedButton(
          onPressed: _loading ? null : _continue,
          style: ElevatedButton.styleFrom(
            minimumSize: const Size.fromHeight(48),
            backgroundColor: cs.primary,
            foregroundColor: cs.onPrimary,
          ),
          child: _loading
              ? const CircularProgressIndicator()
              : Text('Continue to Story', style: tt.labelLarge),
        )
            : Text(
          'Waiting for host to start story…',
          textAlign: TextAlign.center,
          style: tt.bodyLarge,
        ),
      ),
    );
  }
}
