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
      appBar: AppBar(
        centerTitle: true,
        title: Text(
          'Host Lobby',
          style: GoogleFonts.carterOne(color: Colors.black),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      extendBodyBehindAppBar: true,
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFFE3F2FD), Color(0xFFBBDEFB)],
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
                // Join Code Card
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
                            Text(
                              'Join Code:',
                              style: GoogleFonts.kottaOne(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.black),
                            ),
                            const SizedBox(height: 4),
                            SelectableText(
                              joinCode,
                              style: GoogleFonts.kottaOne(
                                  fontSize: 24, color: Colors.black),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Players in Lobby:',
                  style: GoogleFonts.kottaOne(
                      fontWeight: FontWeight.bold, color: Colors.black),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                // Player List
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
                              leading: Text(
                                '${player.slot}',
                                style: GoogleFonts.kottaOne(color: Colors.black),
                              ),
                              title: Text(
                                player.displayName,
                                style: GoogleFonts.kottaOne(color: Colors.black),
                              ),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  if (player.userId == vm.currentUserId)
                                    IconButton(
                                      icon: const Icon(Icons.edit, color: Colors.black),
                                      onPressed: () => _renameMe(context, vm),
                                    ),
                                  if (vm.isHost &&
                                      player.userId != vm.currentUserId)
                                    IconButton(
                                      icon: const Icon(Icons.remove_circle, color: Colors.black),
                                      onPressed: () => _confirmKick(context, player.slot, vm),
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
                // Scalable Quill Image
                LayoutBuilder(
                  builder: (context, constraints) {
                    final size = constraints.maxWidth * 0.2;
                    return Center(
                      child: SizedBox(
                        width: size,
                        height: size,
                        child: Image.asset(
                          'assets/quill_ink.jpg',
                          fit: BoxFit.contain,
                        ),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 16),
                // Action Buttons
                if (vm.isHost && !vm.isResolving && !vm.fromSoloStory && !vm.fromGroupStory)
                  Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 200),
                      child: ElevatedButton(
                        onPressed: vm.startGroupStory,
                        style: ElevatedButton.styleFrom(
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          elevation: 2,
                          backgroundColor: Colors.white.withOpacity(0.9),
                        ),
                        child: Text('Start Group Story', style: GoogleFonts.kottaOne(fontWeight: FontWeight.bold, color: Colors.black)),
                      ),
                    ),
                  ),
                if (vm.isHost && vm.fromSoloStory && !vm.isResolving)
                  Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 200),
                      child: ElevatedButton(
                        onPressed: vm.startSoloStory,
                        style: ElevatedButton.styleFrom(
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          elevation: 2,
                          backgroundColor: Colors.white.withOpacity(0.9),
                        ),
                        child: Text('Go To Story', style: GoogleFonts.kottaOne(fontWeight: FontWeight.bold, color: Colors.black)),
                      ),
                    ),
                  ),
                if (vm.fromGroupStory && !vm.isResolving)
                  Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 200),
                      child: ElevatedButton(
                        onPressed: vm.goToStoryAfterResults,
                        style: ElevatedButton.styleFrom(
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          elevation: 2,
                          backgroundColor: Colors.white.withOpacity(0.9),
                        ),
                        child: Text('Go To Story', style: GoogleFonts.kottaOne(fontWeight: FontWeight.bold, color: Colors.black)),
                      ),
                    ),
                  ),
                if (vm.isResolving) const Center(child: CircularProgressIndicator()),
              ],
            ),
          ),
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
        title: Text('Change Your Name', style: GoogleFonts.kottaOne(color: Colors.black)),
        content: TextField(
          autofocus: true,
          decoration: const InputDecoration(hintText: 'Enter new display name'),
          onChanged: (v) => tmp = v,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel', style: TextStyle(color: Colors.black))),
          TextButton(onPressed: () => Navigator.pop(ctx, tmp), child: const Text('OK', style: TextStyle(color: Colors.black))),
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
    // Placeholder for custom tile implementation
    return Container();
  }
}
