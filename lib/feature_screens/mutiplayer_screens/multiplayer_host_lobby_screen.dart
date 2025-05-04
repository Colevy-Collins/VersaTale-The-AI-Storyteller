// lib/screens/multiplayer_host_lobby_screen.dart
// -----------------------------------------------------------------------------
// Host lobby that scales gracefully from tiny Wear‑OS‑sized screens
// (≈240×340px) all the way up to desktop.  Dialogs are styled to match
// `FullStoryDialog`, using the same max‑width / max‑height pattern.
// -----------------------------------------------------------------------------

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';

import '../../controllers/lobby_host_controller.dart';
import 'vote_results_screen.dart';
import '../story_screen.dart';
import '../dashboard_screen.dart';
import '../../utils/ui_utils.dart';

/// Convenience values for the responsive break‑points we care about.
///  • `_kTinyScreen`  – screens at or below 240×340 (Wear / small phones)
///  • `_kSmallScreen` – up to a ~phone‑sized display
const Size   _kTinyScreen  = Size(240, 340);
const double _kMaxDialogW  = 560;
const double _kMaxDialogH  = 600;

/*──────────────────────── host lobby ────────────────────────*/

class MultiplayerHostLobbyScreen extends StatelessWidget {
  const MultiplayerHostLobbyScreen({
    super.key,
    required this.sessionId,
    required this.joinCode,
    required this.playersMap,
    this.fromSoloStory  = false,
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
        sessionId     : sessionId,
        currentUserId : FirebaseAuth.instance.currentUser!.uid,
        initialPlayers: playersMap,
        fromSoloStory : fromSoloStory,
        fromGroupStory: fromGroupStory,
      ),
      child: _LobbyView(joinCode: joinCode),
    );
  }
}

/*──────────────────── lobby view (state‑less) ───────────────────*/

class _LobbyView extends StatelessWidget {
  const _LobbyView({required this.joinCode});

  final String joinCode;

  /*──────── side‑effects after state changes ────────*/

  void _handleNavigation(BuildContext ctx, LobbyHostController vm) {
    if (vm.lastError != null) {
      showError(ctx, vm.lastError!);
      vm.clearError();
    }

    if (vm.isKicked) {
      Navigator.pushReplacement(ctx,
          MaterialPageRoute(builder: (_) => const HomeScreen()));
      return;
    }

    if (vm.shouldNavigateToResults && vm.resolvedResults != null) {
      Navigator.pushReplacement(
        ctx,
        MaterialPageRoute(
          builder: (_) => VoteResultsScreen(
            resolvedResults: vm.resolvedResults!,
            sessionId      : vm.sessionId,
            joinCode       : joinCode,
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
            sessionId       : vm.sessionId,
            joinCode        : joinCode,
            initialLeg      : vm.storyPayload!['initialLeg'],
            options         : List<String>.from(vm.storyPayload!['options'] ?? []),
            storyTitle      : vm.storyPayload!['storyTitle'],
            inputTokens     : vm.storyPayload!['inputTokens']     ?? 0,
            outputTokens    : vm.storyPayload!['outputTokens']    ?? 0,
            estimatedCostUsd: vm.storyPayload!['estimatedCostUsd'] ?? 0.0,
          ),
        ),
      );
      vm.navigationHandled();
    }
  }

  /*──────── build ────────*/

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<LobbyHostController>();

    // Attach navigation listeners (outside build).
    WidgetsBinding.instance
        .addPostFrameCallback((_) => _handleNavigation(context, vm));

    return LayoutBuilder(
      builder: (context, constraints) {
        final bool isTiny   = constraints.maxWidth  <= _kTinyScreen.width &&
            constraints.maxHeight <= _kTinyScreen.height;
        final EdgeInsetsGeometry pad =
        EdgeInsets.all(isTiny ? 8 : 16);                       // tighter pad
        final double spacing  = isTiny ? 8 : 16;
        final double cardMaxW = isTiny
            ? constraints.maxWidth * 0.9
            : (constraints.maxWidth < 420 ? constraints.maxWidth * 0.8 : 400);
        final double joinCardMaxW = isTiny
            ? constraints.maxWidth * 0.9
            : (constraints.maxWidth < 320 ? constraints.maxWidth * 0.9 : 300);

        final cs = Theme.of(context).colorScheme;
        final tt = Theme.of(context).textTheme;

        /*──────────────────────── scaffold ───────────────────────*/

        return Scaffold(
          extendBodyBehindAppBar: true,
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            elevation      : 0,
            centerTitle    : true,
            title: FittedBox(
              fit : BoxFit.scaleDown,
              child: Text('Host Lobby',
                  style: tt.titleLarge?.copyWith(color: cs.onBackground)),
            ),
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
              child: Padding(
                padding: pad,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    /*──────── join‑code card ────────*/
                    Center(
                      child: ConstrainedBox(
                        constraints:
                        BoxConstraints(maxWidth: joinCardMaxW),
                        child: Card(
                          color: cs.surface.withOpacity(.85),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                                vertical: 12, horizontal: 16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Join Code:',
                                    style: tt.labelLarge?.copyWith(
                                        fontWeight: FontWeight.bold)),
                                const SizedBox(height: 4),
                                // Fit the code on tiny screens.
                                FittedBox(
                                  fit: BoxFit.scaleDown,
                                  child: SelectableText(joinCode,
                                      style: tt.headlineSmall?.copyWith(
                                          fontWeight: FontWeight.bold)),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                    SizedBox(height: spacing),

                    /*──────── players header ────────*/
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text('Players in Lobby:',
                          style: tt.titleMedium
                              ?.copyWith(fontWeight: FontWeight.bold),
                          textAlign: TextAlign.center),
                    ),
                    const SizedBox(height: 8),

                    /*──────── players list ────────*/
                    Expanded(
                      child: Scrollbar(
                        thumbVisibility: !isTiny,
                        child: ListView.builder(
                          itemCount: vm.players.length,
                          itemBuilder: (_, i) {
                            final p = vm.players[i];
                            return Center(
                              child: ConstrainedBox(
                                constraints:
                                BoxConstraints(maxWidth: cardMaxW),
                                child: Card(
                                  margin:
                                  const EdgeInsets.symmetric(vertical: 4),
                                  child: ListTile(
                                    dense: isTiny,
                                    leading: FittedBox(
                                      fit: BoxFit.scaleDown,
                                      child: Text('${p.slot}',
                                          style: tt.titleMedium),
                                    ),
                                    title: FittedBox(
                                      fit: BoxFit.scaleDown,
                                      alignment: Alignment.centerLeft,
                                      child: Text(p.displayName,
                                          style: tt.bodyLarge),
                                    ),
                                    trailing: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        if (p.userId == vm.currentUserId)
                                          IconButton(
                                            icon: const Icon(Icons.edit),
                                            tooltip: 'Rename',
                                            visualDensity: isTiny
                                                ? VisualDensity.compact
                                                : null,
                                            onPressed: () =>
                                                _renameMe(context, vm),
                                          ),
                                        if (vm.isHost &&
                                            p.userId != vm.currentUserId)
                                          IconButton(
                                            icon:
                                            const Icon(Icons.remove_circle),
                                            tooltip: 'Kick',
                                            visualDensity: isTiny
                                                ? VisualDensity.compact
                                                : null,
                                            onPressed: () => _kickPlayer(
                                                context, p.slot, vm),
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
                    ),
                    SizedBox(height: spacing),

                    /*──────── decorative graphic ────────*/
                    if (!isTiny)                       // hide image on tiniest
                      LayoutBuilder(
                        builder: (_, c) {
                          final double sz = (c.maxWidth * 0.2).clamp(40, 120);
                          return Center(
                            child: Image.asset('assets/quill2.png',
                                width: sz, height: sz, fit: BoxFit.contain),
                          );
                        },
                      ),
                    SizedBox(height: spacing),

                    /*──────── bottom‑action buttons ────────*/
                    if (vm.isHost &&
                        vm.players.length > 1 &&
                        !vm.isResolving &&
                        vm.isNewGame &&
                        !vm.fromSoloStory)
                      _actionButton(context,
                          onTap : vm.startSoloStory,
                          label: 'Take Everyone to Story',
                          maxWidth: cardMaxW),
                    if (vm.isHost &&
                        vm.players.length > 1 &&
                        !vm.isResolving &&
                        !vm.isNewGame)
                      _actionButton(context,
                          onTap : vm.startGroupStory,
                          label: 'Take Everyone to Story',
                          maxWidth: cardMaxW),
                    if (vm.isHost && vm.fromSoloStory && !vm.isResolving)
                      _actionButton(context,
                          onTap : vm.goToStoryAfterResults,
                          label: 'Go To Story',
                          maxWidth: cardMaxW),
                    if (vm.fromGroupStory && !vm.isResolving)
                      _actionButton(context,
                          onTap : vm.goToStoryAfterResults,
                          label: 'Go To Story',
                          maxWidth: cardMaxW),
                    if (vm.isResolving)
                      const Center(child: CircularProgressIndicator()),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  /*──────── reusable widgets ────────*/

  Widget _actionButton(
      BuildContext ctx, {
        required VoidCallback onTap,
        required String label,
        required double maxWidth,
      }) {
    final cs = Theme.of(ctx).colorScheme;
    final tt = Theme.of(ctx).textTheme;

    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: cs.primary,
            foregroundColor: cs.onPrimary,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12)),
          ),
          onPressed: onTap,
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(label,
                style:
                tt.labelLarge?.copyWith(fontWeight: FontWeight.bold)),
          ),
        ),
      ),
    );
  }

  /*──────── custom adaptive dialogs ────────*/

  Future<void> _kickPlayer(
      BuildContext ctx, int slot, LobbyHostController vm) async {
    final name = vm.players.firstWhere((p) => p.slot == slot).displayName;
    final bool? ok = await showDialog<bool>(
      context: ctx,
      builder: (_) => _AdaptiveConfirmDialog(
        title  : 'Kick Player',
        message: 'Remove $name from lobby?',
        confirmLabel: 'Remove',
      ),
    );
    if (ok == true) {
      vm.kickPlayer(slot);
      showSnack(ctx, 'Removed $name');
    }
  }

  Future<void> _renameMe(BuildContext ctx, LobbyHostController vm) async {
    String tmp = '';
    final String? newName = await showDialog<String>(
      context: ctx,
      builder: (_) => _AdaptiveInputDialog(
        title   : 'Change Your Name',
        hintText: 'Enter new display name',
        onChanged: (v) => tmp = v,
      ),
    );
    if (newName != null && newName.trim().isNotEmpty) {
      vm.changeMyName(newName.trim());
      showSnack(ctx, 'Name updated to ${newName.trim()}');
    }
  }
}

/*──────────────────────── dialog helpers ───────────────────────*/

class _AdaptiveConfirmDialog extends StatelessWidget {
  const _AdaptiveConfirmDialog({
    required this.title,
    required this.message,
    this.confirmLabel = 'OK',
  });

  final String title;
  final String message;
  final String confirmLabel;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final Size   screen   = MediaQuery.of(context).size;
    final double maxW     = screen.width  < _kMaxDialogW
        ? screen.width  * 0.95
        : _kMaxDialogW;
    final double maxH     = screen.height < _kMaxDialogH
        ? screen.height * 0.85
        : _kMaxDialogH;

    return Dialog(
      insetPadding: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      backgroundColor: cs.surface,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxW, maxHeight: maxH),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Text(title,
                    style: tt.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
              ),
              const SizedBox(height: 12),
              Text(message, style: tt.bodyLarge),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                      onPressed: Navigator.of(context).pop,
                      child: const Text('Cancel')),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: () => Navigator.pop(context, true),
                    child: Text(confirmLabel),
                  ),
                ],
              )
            ],
          ),
        ),
      ),
    );
  }
}

class _AdaptiveInputDialog extends StatefulWidget {
  const _AdaptiveInputDialog({
    required this.title,
    this.hintText,
    required this.onChanged,
  });

  final String title;
  final String? hintText;
  final ValueChanged<String> onChanged;

  @override
  State<_AdaptiveInputDialog> createState() => _AdaptiveInputDialogState();
}

class _AdaptiveInputDialogState extends State<_AdaptiveInputDialog> {
  final TextEditingController _ctrl = TextEditingController();

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final Size screen = MediaQuery.of(context).size;
    final double maxW = screen.width  < _kMaxDialogW
        ? screen.width  * 0.95
        : _kMaxDialogW;
    final double maxH = screen.height < _kMaxDialogH
        ? screen.height * 0.85
        : _kMaxDialogH;

    return Dialog(
      insetPadding: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      backgroundColor: cs.surface,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxW, maxHeight: maxH),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Text(widget.title,
                    style: tt.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
              ),
              const SizedBox(height: 12),
              TextField(
                controller : _ctrl,
                autofocus  : true,
                decoration : InputDecoration(
                    hintText: widget.hintText ?? '',
                    border  : const OutlineInputBorder()),
                onChanged  : widget.onChanged,
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                      onPressed: Navigator.of(context).pop,
                      child: const Text('Cancel')),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: () => Navigator.pop(context, _ctrl.text),
                    child: const Text('OK'),
                  ),
                ],
              )
            ],
          ),
        ),
      ),
    );
  }
}
