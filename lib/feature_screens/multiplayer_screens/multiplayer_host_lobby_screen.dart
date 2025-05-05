// lib/screens/multiplayer_host_lobby_screen.dart
// ---------------------------------------------------------------------------
// Host‑lobby screen – fully scrollable down to 240 × 340 px while preserving
// all original functionality: rename, kick, start solo/group story, resume
// story after results, error handling, snack bars, etc.
// ---------------------------------------------------------------------------

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../controllers/lobby_host_controller.dart';
import '../../utils/ui_utils.dart';
import '../../widgets/adaptive_dialogs.dart';
import '../../widgets/primary_action_button.dart';
import '../dashboard_screen.dart';
import '../story_screen.dart';
import 'vote_results_screen.dart';

/*──────── constants ─────────────────────────────────────────*/
const Size   _kWearSize = Size(240, 340); // tiniest target screen
const double _kCardMax  = 400.0;          // max width for list cards

/*──────── wrapper ───────────────────────────────────────────*/
class MultiplayerHostLobbyScreen extends StatelessWidget {
  const MultiplayerHostLobbyScreen({
    super.key,
    required this.sessionId,
    required this.joinCode,
    required this.initialPlayers,
    this.fromSoloStory  = false,
    this.fromGroupStory = false,
  });

  final String sessionId;
  final String joinCode;
  final Map<int, Map<String, dynamic>> initialPlayers;
  final bool fromSoloStory;
  final bool fromGroupStory;

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => LobbyHostController(
        sessionId     : sessionId,
        currentUserId : FirebaseAuth.instance.currentUser!.uid,
        initialPlayers: initialPlayers,
        fromSoloStory : fromSoloStory,
        fromGroupStory: fromGroupStory,
      ),
      child: _HostLobbyView(joinCode: joinCode),
    );
  }
}

/*──────────────── view ─────────────────────────────────────*/
class _HostLobbyView extends StatelessWidget {
  const _HostLobbyView({required this.joinCode});

  final String joinCode;

  /*── centralised navigation side‑effects ─*/
  void _handleNavigation(BuildContext ctx, LobbyHostController c) {
    if (c.lastError != null) {
      showError(ctx, c.lastError!);
      c.clearError();
    }

    if (c.isKicked) {
      Navigator.pushReplacement(
        ctx,
        MaterialPageRoute(builder: (_) => const HomeScreen()),
      );
      return;
    }

    if (c.shouldNavigateToResults && c.resolvedResults != null) {
      Navigator.pushReplacement(
        ctx,
        MaterialPageRoute(
          builder: (_) => VoteResultsScreen(
            resolvedResults: c.resolvedResults!,
            sessionId      : c.sessionId,
            joinCode       : joinCode,
          ),
        ),
      );
      c.navigationHandled();
      return;
    }

    if (c.shouldNavigateToStory && c.storyPayload != null) {
      final p = c.storyPayload!;
      Navigator.pushReplacement(
        ctx,
        MaterialPageRoute(
          builder: (_) => StoryScreen(
            sessionId       : c.sessionId,
            joinCode        : joinCode,
            initialLeg      : p['initialLeg'],
            options         : List<String>.from(p['options'] ?? const []),
            storyTitle      : p['storyTitle'],
            inputTokens     : p['inputTokens']     ?? 0,
            outputTokens    : p['outputTokens']    ?? 0,
            estimatedCostUsd: p['estimatedCostUsd'] ?? 0.0,
          ),
        ),
      );
      c.navigationHandled();
    }
  }

  /*── helpers ───────────────────────────────────────────────*/
  Future<void> _copyJoinCode(BuildContext ctx) async {
    await Clipboard.setData(ClipboardData(text: joinCode));
    showSnack(ctx, 'Join code copied');
  }

  Future<void> _kickPlayer(
      BuildContext ctx, int slot, LobbyHostController c) async {
    final name = c.players.firstWhere((p) => p.slot == slot).displayName;
    final ok = await confirmDialog(
      ctx         : ctx,
      title       : 'Kick player',
      message     : 'Remove $name from lobby?',
      confirmLabel: 'Kick',
    );
    if (ok) {
      c.kickPlayer(slot);
      showSnack(ctx, 'Removed $name');
    }
  }

  Future<void> _renameSelf(BuildContext ctx, LobbyHostController c) async {
    final newName = await showDialog<String>(
      context: ctx,
      builder: (_) => const AdaptiveInputDialog(
        title   : 'Change your name',
        hintText: 'Display name',
      ),
    );
    if (newName != null && newName.trim().isNotEmpty) {
      c.changeMyName(newName.trim());
      showSnack(ctx, 'Name updated');
    }
  }

  /*── build ────────────────────────────────────────────────*/
  @override
  Widget build(BuildContext context) {
    final lobby = context.watch<LobbyHostController>();

    // Run navigation side‑effects after the first frame of every build
    WidgetsBinding.instance
        .addPostFrameCallback((_) => _handleNavigation(context, lobby));

    return LayoutBuilder(
      builder: (ctx, constraints) {
        final isWear =
            constraints.maxWidth <= _kWearSize.width &&
                constraints.maxHeight <= _kWearSize.height;

        final double outerPad = isWear ? 8 : 16;
        final double gap      = isWear ? 8 : 16;

        final cs = Theme.of(ctx).colorScheme;
        final tt = Theme.of(ctx).textTheme;

        final double cardMaxW = isWear
            ? constraints.maxWidth * .9
            : (constraints.maxWidth < 420
            ? constraints.maxWidth * .8
            : _kCardMax);

        final double joinCardW = isWear
            ? constraints.maxWidth * .9
            : (constraints.maxWidth < 320
            ? constraints.maxWidth * .9
            : 300.0); // ensure double literal

        return Scaffold(
          extendBodyBehindAppBar: true,
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            elevation      : 0,
            centerTitle    : true,
            title: FittedBox(
              fit : BoxFit.scaleDown,
              child: Text('Host lobby',
                  style: tt.titleLarge?.copyWith(color: cs.onBackground)),
            ),
            actions: [
              IconButton(
                tooltip : 'Tutorial',
                icon    : const Icon(Icons.help_outline),
                onPressed: () => openTutorialPdf(ctx),
              ),
            ],
          ),
          body: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [cs.primaryContainer, cs.secondaryContainer],
                begin : Alignment.topLeft,
                end   : Alignment.bottomRight,
              ),
            ),
            child: SafeArea(
              child: CustomScrollView(
                slivers: [
                  /*──────── join‑code card ─*/
                  SliverPadding(
                    padding: EdgeInsets.all(outerPad),
                    sliver : SliverToBoxAdapter(
                      child: Center(
                        child: ConstrainedBox(
                          constraints: BoxConstraints(maxWidth: joinCardW),
                          child: Card(
                            color : cs.surface.withOpacity(.90),
                            shape : RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12)),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                  vertical: 12, horizontal: 16),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                      children: [
                                        Text('Join code:',
                                            style: tt.labelLarge?.copyWith(
                                                fontWeight: FontWeight.bold)),
                                        const SizedBox(height: 4),
                                        FittedBox(
                                          fit: BoxFit.scaleDown,
                                          child: SelectableText(joinCode,
                                              style: tt.headlineSmall?.copyWith(
                                                  fontWeight:
                                                  FontWeight.bold)),
                                        ),
                                      ],
                                    ),
                                  ),
                                  IconButton(
                                    tooltip : 'Copy',
                                    icon    : const Icon(Icons.copy),
                                    onPressed: () => _copyJoinCode(ctx),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),

                  /*──────── header ─*/
                  SliverPadding(
                    padding: EdgeInsets.symmetric(horizontal: outerPad),
                    sliver : SliverToBoxAdapter(
                      child: Column(
                        children: [
                          FittedBox(
                            fit : BoxFit.scaleDown,
                            child: Text('Players in lobby',
                                style: tt.titleMedium?.copyWith(
                                    fontWeight: FontWeight.bold)),
                          ),
                          const SizedBox(height: 8),
                        ],
                      ),
                    ),
                  ),

                  /*──────── players list ─*/
                  SliverPadding(
                    padding: EdgeInsets.symmetric(horizontal: outerPad),
                    sliver : SliverList.builder(
                      itemCount: lobby.players.length,
                      itemBuilder: (_, i) {
                        final p = lobby.players[i];
                        return Center(
                          child: ConstrainedBox(
                            constraints: BoxConstraints(maxWidth: cardMaxW),
                            child: Card(
                              margin:
                              const EdgeInsets.symmetric(vertical: 4),
                              child: ListTile(
                                dense : isWear,
                                leading: FittedBox(
                                  fit: BoxFit.scaleDown,
                                  child: Text('${p.slot}', style: tt.titleMedium),
                                ),
                                title: FittedBox(
                                  fit       : BoxFit.scaleDown,
                                  alignment : Alignment.centerLeft,
                                  child     : Text(p.displayName,
                                      style: tt.bodyLarge),
                                ),
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    if (p.userId == lobby.currentUserId)
                                      IconButton(
                                        icon        : const Icon(Icons.edit),
                                        tooltip     : 'Rename',
                                        visualDensity: isWear
                                            ? VisualDensity.compact
                                            : null,
                                        onPressed   : () =>
                                            _renameSelf(ctx, lobby),
                                      ),
                                    if (lobby.isHost &&
                                        p.userId != lobby.currentUserId)
                                      IconButton(
                                        icon        : const Icon(Icons.remove_circle),
                                        tooltip     : 'Kick',
                                        visualDensity: isWear
                                            ? VisualDensity.compact
                                            : null,
                                        onPressed   : () =>
                                            _kickPlayer(ctx, p.slot, lobby),
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

                  /*──────── bottom actions / loader ─*/
                  SliverPadding(
                    padding: EdgeInsets.fromLTRB(
                        outerPad, gap, outerPad, outerPad),
                    sliver : SliverToBoxAdapter(
                      child: Column(
                        children: [
                          // Host can start a brand‑new solo story for all
                          if (lobby.isHost &&
                              lobby.players.length > 1 &&
                              !lobby.isResolving &&
                              lobby.isNewGame &&
                              !lobby.fromSoloStory)
                            PrimaryActionButton(
                              label    : 'Take everyone to story',
                              onPressed: lobby.startSoloStory,
                              maxWidth : cardMaxW,
                            ),

                          // Host can resume the existing group story for all
                          if (lobby.isHost &&
                              lobby.players.length > 1 &&
                              !lobby.isResolving &&
                              !lobby.isNewGame)
                            PrimaryActionButton(
                              label    : 'Take everyone to story',
                              onPressed: lobby.startGroupStory,
                              maxWidth : cardMaxW,
                            ),

                          // Anyone returning from a solo round → go back alone
                          if (lobby.fromSoloStory && !lobby.isResolving)
                            PrimaryActionButton(
                              label    : 'Go to story',
                              onPressed: lobby.goToStoryAfterResults,
                              maxWidth : cardMaxW,
                            ),

                          // Anyone (host OR joiner) returning from a group round
                          if (lobby.fromGroupStory && !lobby.isResolving)
                            PrimaryActionButton(
                              label    : 'Go to story',
                              onPressed: lobby.goToStoryAfterResults,
                              maxWidth : cardMaxW,
                            ),

                          // Show spinner while results resolve
                          if (lobby.isResolving)
                            const Padding(
                              padding:
                              EdgeInsets.symmetric(vertical: 16),
                              child: CircularProgressIndicator(),
                            ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
