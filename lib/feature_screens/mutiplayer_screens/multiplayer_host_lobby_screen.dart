// lib/screens/multiplayer_host_lobby_screen.dart
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';

import '../../controllers/lobby_host_controller.dart';
import 'vote_results_screen.dart';
import '../story_screen.dart';
import '../dashboard_screen.dart';
import '../../utils/ui_utils.dart';

class MultiplayerHostLobbyScreen extends StatelessWidget {
  const MultiplayerHostLobbyScreen({
    super.key,
    required this.sessionId,
    required this.joinCode,
    required this.playersMap,
    this.fromSoloStory = false,
    this.fromGroupStory = false,
  });

  final String sessionId;
  final String joinCode;
  final Map<int, Map<String, dynamic>> playersMap;
  final bool fromSoloStory;
  final bool fromGroupStory;

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<LobbyHostController>(
      create: (_) => LobbyHostController(
        sessionId: sessionId,
        currentUserId: FirebaseAuth.instance.currentUser!.uid,
        initialPlayers: playersMap,
        fromSoloStory: fromSoloStory,
        fromGroupStory: fromGroupStory,
      ),
      child: _LobbyView(joinCode: joinCode),
    );
  }
}

/* ─────────────────────────────────────────────────────────────────── */

class _LobbyView extends StatelessWidget {
  const _LobbyView({required this.joinCode});

  final String joinCode;

  /* ───────── side-effects after state changes ───────── */

  void _handleNavigation(BuildContext ctx, LobbyHostController vm) {
    if (vm.lastError != null) {
      showError(ctx, vm.lastError!);
      vm.clearError();
    }

    if (vm.isKicked) {
      Navigator.pushReplacement(
        ctx,
        MaterialPageRoute(builder: (_) => const HomeScreen()),
      );
      return;
    }

    if (vm.shouldNavigateToResults && vm.resolvedResults != null) {
      Navigator.pushReplacement(
        ctx,
        MaterialPageRoute(
          builder: (_) => VoteResultsScreen(
            resolvedResults: vm.resolvedResults!,
            sessionId: vm.sessionId,
            joinCode: joinCode,
          ),
        ),
      );
      vm.navigationHandled();
      return;
    }

    if (vm.shouldNavigateToStory && vm.storyPayload != null) {
      Navigator.pushReplacement(
        ctx,
        MaterialPageRoute(
          builder: (_) => StoryScreen(
            sessionId: vm.sessionId,
            joinCode: joinCode,
            initialLeg: vm.storyPayload!['initialLeg'],
            options: List<String>.from(vm.storyPayload!['options'] ?? []),
            storyTitle: vm.storyPayload!['storyTitle'],
            inputTokens: vm.storyPayload!['inputTokens'] ?? 0,
            outputTokens: vm.storyPayload!['outputTokens'] ?? 0,
            estimatedCostUsd: vm.storyPayload!['estimatedCostUsd'] ?? 0.0,
          ),
        ),
      );
      vm.navigationHandled();
    }
  }

  /* ───────── build ───────── */

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<LobbyHostController>();

    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    // Attach navigation listeners.
    WidgetsBinding.instance
        .addPostFrameCallback((_) => _handleNavigation(context, vm));

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        title: Text(
          'Host Lobby',
          style: tt.titleLarge?.copyWith(color: cs.onBackground),
        ),
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [cs.primaryContainer, cs.secondaryContainer],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                /* ── Join-code card ── */
                Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 300),
                    child: Card(
                      color: cs.surface.withOpacity(.85),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          vertical: 12,
                          horizontal: 16,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Join Code:',
                              style: tt.labelLarge?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 4),
                            SelectableText(
                              joinCode,
                              style: tt.headlineSmall?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                /* ── Players list ── */
                Text(
                  'Players in Lobby:',
                  style: tt.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: ListView.builder(
                    itemCount: vm.players.length,
                    itemBuilder: (_, i) {
                      final p = vm.players[i];
                      return Center(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 400),
                          child: Card(
                            margin: const EdgeInsets.symmetric(vertical: 4),
                            child: ListTile(
                              leading: Text(
                                '${p.slot}',
                                style: tt.titleMedium,
                              ),
                              title: Text(
                                p.displayName,
                                style: tt.bodyLarge,
                              ),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  if (p.userId == vm.currentUserId)
                                    IconButton(
                                      icon: const Icon(Icons.edit),
                                      onPressed: () => _renameMe(context, vm),
                                    ),
                                  if (vm.isHost &&
                                      p.userId != vm.currentUserId)
                                    IconButton(
                                      icon: const Icon(Icons.remove_circle),
                                      onPressed: () =>
                                          _kickPlayer(context, p.slot, vm),
                                    ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 16),

                /* ── Decorative image ── */
                LayoutBuilder(
                  builder: (_, c) {
                    final sz = c.maxWidth * 0.2;
                    return Center(
                      child: Image.asset(
                        'assets/quill2.png',
                        width: sz,
                        height: sz,
                        fit: BoxFit.contain,
                      ),
                    );
                  },
                ),
                const SizedBox(height: 16),

                /* ── Bottom-action buttons ── */
                if (vm.isHost &&
                    vm.players.length > 1 &&
                    !vm.isResolving &&
                    vm.isNewGame &&
                    !vm.fromSoloStory)
                  _actionButton(
                    context,
                    onTap: vm.startSoloStory,
                    label: 'Take Everyone to Story',
                  ),
                if (vm.isHost &&
                    vm.players.length > 1 &&
                    !vm.isResolving &&
                    !vm.isNewGame)
                  _actionButton(
                    context,
                    onTap: vm.startGroupStory,
                    label: 'Take Everyone to Story',
                  ),
                if (vm.isHost && vm.fromSoloStory && !vm.isResolving)
                  _actionButton(
                    context,
                    onTap: vm.goToStoryAfterResults,
                    label: 'Go To Story',
                  ),
                if (vm.fromGroupStory && !vm.isResolving)
                  _actionButton(
                    context,
                    onTap: vm.goToStoryAfterResults,
                    label: 'Go To Story',
                  ),
                if (vm.isResolving)
                  const Center(child: CircularProgressIndicator()),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /* ───────── reusable widgets ───────── */

  Widget _actionButton(
      BuildContext ctx, {
        required VoidCallback onTap,
        required String label,
      }) {
    final cs = Theme.of(ctx).colorScheme;
    final tt = Theme.of(ctx).textTheme;

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 220),
        child: ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: cs.primary,
            foregroundColor: cs.onPrimary,
            shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          onPressed: onTap,
          child: Text(
            label,
            style: tt.labelLarge?.copyWith(fontWeight: FontWeight.bold),
          ),
        ),
      ),
    );
  }

  /* ───────── rename / kick helpers ───────── */

  Future<void> _kickPlayer(
      BuildContext ctx, int slot, LobbyHostController vm) async {
    final name = vm.players.firstWhere((p) => p.slot == slot).displayName;
    final ok = await confirmDialog(
      ctx: ctx,
      title: 'Kick Player',
      message: 'Remove $name from lobby?',
    );
    if (ok == true) {
      vm.kickPlayer(slot);
      showSnack(ctx, 'Removed $name');
    }
  }

  Future<void> _renameMe(
      BuildContext ctx, LobbyHostController vm) async {
    String tmp = '';
    final newName = await showDialog<String>(
      context: ctx,
      builder: (_) => AlertDialog(
        title: const Text('Change Your Name'),
        content: TextField(
          autofocus: true,
          decoration:
          const InputDecoration(hintText: 'Enter new display name'),
          onChanged: (v) => tmp = v,
        ),
        actions: [
          TextButton(
            onPressed: Navigator.of(ctx).pop,
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, tmp),
            child: const Text('OK'),
          ),
        ],
      ),
    );
    if (newName != null && newName.trim().isNotEmpty) {
      vm.changeMyName(newName.trim());
      showSnack(ctx, 'Name updated to ${newName.trim()}');
    }
  }
}
