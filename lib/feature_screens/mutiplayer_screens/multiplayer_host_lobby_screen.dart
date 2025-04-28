// lib/screens/multiplayer_host_lobby_screen.dart
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
  final Map<int, Map<String, dynamic>> playersMap;
  final bool fromSoloStory;
  final bool fromGroupStory;

  const MultiplayerHostLobbyScreen({
    Key? key,
    required this.sessionId,
    required this.joinCode,
    required this.playersMap,
    this.fromSoloStory  = false,
    this.fromGroupStory = false,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<LobbyHostController>(
      create: (_) => LobbyHostController(
        sessionId    : sessionId,
        currentUserId: FirebaseAuth.instance.currentUser!.uid,
        initialPlayers: playersMap,
        fromSoloStory : fromSoloStory,
        fromGroupStory: fromGroupStory,
      ),
      child: _LobbyHostView(joinCode: joinCode),
    );
  }
}

/* ────────────────────────────────────────────────────────────────────────── */

class _LobbyHostView extends StatelessWidget {
  final String joinCode;
  const _LobbyHostView({Key? key, required this.joinCode}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<LobbyHostController>();

    /* ── navigation side-effects after state change ── */
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (vm.lastError != null) {
        showError(context, vm.lastError!);
        vm.clearError();
      }

      if (vm.isKicked) {
        Navigator.pushReplacement(context,
            MaterialPageRoute(builder: (_) => HomeScreen()));
      } else if (vm.shouldNavigateToResults &&
          vm.resolvedResults != null) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => VoteResultsScreen(
              resolvedResults: vm.resolvedResults!,
              sessionId      : vm.sessionId,
              joinCode       : joinCode,
            ),
          ),
        );
        vm.navigationHandled();
      } else if (vm.shouldNavigateToStory && vm.storyPayload != null) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => StoryScreen(
              sessionId : vm.sessionId,
              joinCode  : joinCode,
              initialLeg: vm.storyPayload!['initialLeg'],
              options   : List<String>.from(vm.storyPayload!['options'] ?? []),
              storyTitle: vm.storyPayload!['storyTitle'],
              /* ── seed usage counters so badge correct on first frame ── */
              inputTokens     : vm.storyPayload!['inputTokens']     ?? 0,
              outputTokens    : vm.storyPayload!['outputTokens']    ?? 0,
              estimatedCostUsd: vm.storyPayload!['estimatedCostUsd']?? 0.0,
            ),
          ),
        );
        vm.navigationHandled();
      }
    });

    /* ───────────────────── UI scaffold ───────────────────── */
    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        title: Text('Host Lobby', style: GoogleFonts.carterOne(color: Colors.black)),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      extendBodyBehindAppBar: true,
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFFE3F2FD), Color(0xFFBBDEFB)],
            begin : Alignment.topLeft,
            end   : Alignment.bottomRight,
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                /* ── join code card ── */
                Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 300),
                    child: Card(
                      color: Colors.white.withOpacity(0.8),
                      elevation: 2,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8)),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                            vertical: 12, horizontal: 16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Join Code:',
                                style: GoogleFonts.kottaOne(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.black)),
                            const SizedBox(height: 4),
                            SelectableText(joinCode,
                                style: GoogleFonts.kottaOne(
                                    fontSize: 24, color: Colors.black)),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                /* ── players list ── */
                Text('Players in Lobby:',
                    style: GoogleFonts.kottaOne(
                        fontWeight: FontWeight.bold, color: Colors.black),
                    textAlign: TextAlign.center),
                const SizedBox(height: 8),
                Expanded(
                  child: ListView.builder(
                    itemCount: vm.players.length,
                    itemBuilder: (_, i) {
                      final player = vm.players[i];
                      return Center(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 400),
                          child: Card(
                            margin: const EdgeInsets.symmetric(vertical: 4),
                            elevation: 2,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8)),
                            child: ListTile(
                              leading: Text('${player.slot}',
                                  style: GoogleFonts.kottaOne(color: Colors.black)),
                              title: Text(player.displayName,
                                  style: GoogleFonts.kottaOne(color: Colors.black)),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  if (player.userId == vm.currentUserId)
                                    IconButton(
                                        icon : const Icon(Icons.edit, color: Colors.black),
                                        onPressed: () => _renameMe(context, vm)),
                                  if (vm.isHost &&
                                      player.userId != vm.currentUserId)
                                    IconButton(
                                        icon : const Icon(Icons.remove_circle, color: Colors.black),
                                        onPressed: () => _confirmKick(context, player.slot, vm)),
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
                /* ── quill image ── */
                LayoutBuilder(
                  builder: (context, constr) {
                    final sz = constr.maxWidth * 0.2;
                    return Center(
                      child: SizedBox(
                        width : sz,
                        height: sz,
                        child: Image.asset('assets/quill_ink.jpg', fit: BoxFit.contain),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 16),

                /* ── action buttons ── */
                if (vm.isHost &&
                    vm.players.length > 1 &&
                    !vm.isResolving &&
                    vm.isNewGame &&
                    !vm.fromSoloStory)
                  _lobbyButton(vm.startSoloStory, 'Take Everyone to Story'),
                const SizedBox(height: 16),
                if (vm.isHost &&
                    vm.players.length > 1 &&
                    !vm.isResolving &&
                    !vm.isNewGame)
                  _lobbyButton(vm.startGroupStory, 'Take Everyone to Story'),
                const SizedBox(height: 16),
                if (vm.isHost && vm.fromSoloStory && !vm.isResolving)
                  _lobbyButton(vm.goToStoryAfterResults, 'Go To Story'),
                if (vm.fromGroupStory && !vm.isResolving)
                  _lobbyButton(vm.goToStoryAfterResults, 'Go To Story'),
                if (vm.isResolving) const Center(child: CircularProgressIndicator()),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /* ───────── helpers ───────── */

  Widget _lobbyButton(VoidCallback onTap, String label) => Center(
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 200),
      child: ElevatedButton(
        onPressed: onTap,
        style: ElevatedButton.styleFrom(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          elevation: 2,
          backgroundColor: Colors.white.withOpacity(0.9),
        ),
        child: Text(label,
            style: GoogleFonts.kottaOne(fontWeight: FontWeight.bold, color: Colors.black)),
      ),
    ),
  );

  Future<void> _confirmKick(
      BuildContext ctx, int slot, LobbyHostController vm) async {
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
        title: Text('Change Your Name',
            style: GoogleFonts.kottaOne(color: Colors.black)),
        content: TextField(
          autofocus: true,
          decoration: const InputDecoration(hintText: 'Enter new display name'),
          onChanged: (v) => tmp = v,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel', style: TextStyle(color: Colors.black))),
          TextButton(onPressed: () => Navigator.pop(ctx, tmp),
              child: const Text('OK', style: TextStyle(color: Colors.black))),
        ],
      ),
    );
    if (newName != null && newName.trim().isNotEmpty) {
      vm.changeMyName(newName.trim());
      showSnack(ctx, 'Name updated to ${newName.trim()}');
    }
  }
}
