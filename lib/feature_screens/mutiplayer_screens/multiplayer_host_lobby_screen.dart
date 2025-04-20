// lib/screens/multiplayer_host_lobby_screen.dart
// -----------------------------------------------------------------------------
// Host lobby screen (host side) with full feature‑parity to the original
// but refactored for SRP. All heavy lifting is delegated to LobbyHostController.
// -----------------------------------------------------------------------------

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../controllers/lobby_host_controller.dart';
import 'vote_results_screen.dart';
import '../story_screen.dart';
import '../dashboard_screen.dart';
import '../../models/player.dart';
import '../../utils/ui_utils.dart';

class MultiplayerHostLobbyScreen extends StatelessWidget {
  final String sessionId;
  final String joinCode;
  final Map<int, Map<String, dynamic>> playersMap; // initial snapshot
  final bool fromSoloStory;
  final bool fromGroupStory;

  const MultiplayerHostLobbyScreen({
    Key? key,
    required this.sessionId,
    required this.joinCode,
    required this.playersMap,
    this.fromSoloStory = false,
    this.fromGroupStory = false,
  }) : super(key: key);

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
      child: _LobbyHostView(joinCode: joinCode),
    );
  }
}

class _LobbyHostView extends StatelessWidget {
  final String joinCode;
  const _LobbyHostView({Key? key, required this.joinCode}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<LobbyHostController>();

    // ------- side‑effects: navigation & errors ---------
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (vm.lastError != null) {
        showError(context, vm.lastError!);
        vm.clearError();
      }

      if (vm.isKicked) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => HomeScreen()),
        );
      } else if (vm.shouldNavigateToResults && vm.resolvedResults != null) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => VoteResultsScreen(
              resolvedResults: vm.resolvedResults!,
              sessionId: vm.sessionId,
              joinCode: joinCode,
            ),
          ),
        );
        vm.navigationHandled();
      } else if (vm.shouldNavigateToStory && vm.storyPayload != null) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => StoryScreen(
              sessionId: vm.sessionId,
              initialLeg: vm.storyPayload!['initialLeg'],
              options: List<String>.from(vm.storyPayload!['options'] ?? []),
              storyTitle: vm.storyPayload!['storyTitle'],
              joinCode: joinCode,
            ),
          ),
        );
        vm.navigationHandled();
      }
    });

    return Scaffold(
      appBar: AppBar(title: Text('Host Lobby', style: GoogleFonts.atma())),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Join Code:', style: GoogleFonts.atma(fontWeight: FontWeight.bold)),
            SelectableText(joinCode, style: GoogleFonts.atma(fontSize: 24)),
            const SizedBox(height: 16),
            Text('Players in Lobby:', style: GoogleFonts.atma(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Expanded(
              child: ListView.builder(
                itemCount: vm.players.length,
                itemBuilder: (_, i) => _PlayerTile(
                  player: vm.players[i],
                  isHost: vm.isHost,
                  isMe: vm.players[i].userId == vm.currentUserId,
                  onKick: () => _confirmKick(context, vm.players[i].slot, vm),
                  onRename: vm.players[i].userId == vm.currentUserId
                      ? () => _renameMe(context, vm)
                      : null,
                ),
              ),
            ),
            const SizedBox(height: 16),
            if (vm.isHost && !vm.isResolving && !vm.fromSoloStory && !vm.fromGroupStory)
              ElevatedButton(
                onPressed: vm.startGroupStory,
                child: Text('Start Group Story', style: GoogleFonts.atma(fontWeight: FontWeight.bold)),
              ),
            if (vm.isHost && vm.fromSoloStory && !vm.isResolving)
              ElevatedButton(
                onPressed: vm.startSoloStory,
                child: Text('Go To Story', style: GoogleFonts.atma(fontWeight: FontWeight.bold)),
              ),
            if (vm.fromGroupStory && !vm.isResolving)
              ElevatedButton(
                onPressed: vm.goToStoryAfterResults,
                child: Text('Go To Story', style: GoogleFonts.atma(fontWeight: FontWeight.bold)),
              ),
            if (vm.isResolving)
              const Center(child: CircularProgressIndicator()),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmKick(BuildContext ctx, int slot, LobbyHostController vm) async {
    final name = vm.players.firstWhere((p) => p.slot == slot).displayName;
    final kick = await confirmDialog(
      ctx: ctx,
      title: 'Kick Player',
      message: 'Remove $name from lobby?',
    );
    if (kick == true) {
      vm.kickPlayer(slot);
      showSnack(ctx, 'Removed $name');
    }
  }

  Future<void> _renameMe(BuildContext ctx, LobbyHostController vm) async {
    String tmp = '';
    final newName = await showDialog<String>(
      context: ctx,
      builder: (_) => AlertDialog(
        title: Text('Change Your Name', style: GoogleFonts.atma()),
        content: TextField(
          autofocus: true,
          decoration: const InputDecoration(hintText: 'Enter new display name'),
          onChanged: (v) => tmp = v,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(ctx, tmp), child: const Text('OK')),
        ],
      ),
    );
    if (newName != null && newName.trim().isNotEmpty) {
      vm.changeMyName(newName.trim());
      showSnack(ctx, 'Name updated to ${newName.trim()}');
    }
  }
}

class _PlayerTile extends StatelessWidget {
  final Player player;
  final bool isHost;
  final bool isMe;
  final VoidCallback? onKick;
  final VoidCallback? onRename;

  const _PlayerTile({
    Key? key,
    required this.player,
    required this.isHost,
    required this.isMe,
    this.onKick,
    this.onRename,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Text('${player.slot}', style: GoogleFonts.atma()),
      title: Text(player.displayName, style: GoogleFonts.atma()),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (isMe)
            IconButton(icon: const Icon(Icons.edit), onPressed: onRename),
          if (isHost && !isMe)
            IconButton(icon: const Icon(Icons.remove_circle), onPressed: onKick),
        ],
      ),
    );
  }
}
