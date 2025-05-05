import 'dart:math';
import 'package:flutter/material.dart';

import 'dart:math';
import 'package:flutter/material.dart';

import 'login_screens/main_splash_screen.dart';
import 'new_story_screens/create_new_story_screen.dart';
import 'story_archives_screen.dart';
import 'story_screen.dart';
import 'multiplayer_screens/join_multiplayer_screen.dart';
import '../services/story_service.dart';
import '../services/auth_service.dart';
import '../utils/ui_utils.dart';
import 'profile_screen.dart';

// Extracted widgets / dialogs
import '../widgets/dashboard_background.dart';
import '../widgets/dashboard_button.dart';
import '../widgets/story_options_dialog.dart';

/// Home dashboard – start / continue stories, manage profile, etc.
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  /* ───────── navigation helpers ───────── */

  void _push(BuildContext c, Widget p) =>
      Navigator.push(c, MaterialPageRoute(builder: (_) => p));

  void _toProfile(BuildContext c) => _push(c, const ProfileScreen());
  void _toArchives(BuildContext c) => _push(c, const StoryArchivesScreen());
  void _toNew(BuildContext c, {required bool group}) =>
      _push(c, CreateNewStoryScreen(isGroup: group));
  void _toJoin(BuildContext c) => _push(c, const JoinMultiplayerScreen());

  Future<void> _resumeSolo(BuildContext ctx) async {
    try {
      final active = await StoryService().getActiveStory();
      if (active == null ||
          active['storyLeg'] == 'No story leg returned.' ||
          (active['storyLeg'] as String).length < 2) {
        showSnack(ctx, 'No active story found.');
        return;
      }
      _push(
        ctx,
        StoryScreen(
          initialLeg: active['storyLeg'] ?? '',
          options: List<String>.from(active['options'] ?? []),
          storyTitle: active['storyTitle'] ?? '',
          inputTokens: active['inputTokens'] ?? 0,
          outputTokens: active['outputTokens'] ?? 0,
          estimatedCostUsd: active['estimatedCostUsd'] ?? 0.0,
        ),
      );
    } catch (e) {
      showError(ctx, 'Error resuming active story: $e');
    }
  }

  void _storyOptions(BuildContext ctx) {
    showDialog(
      context: ctx,
      builder: (_) => StoryOptionsDialog(
        onStartStory: (g) {
          Navigator.pop(ctx);
          _toNew(ctx, group: g);
        },
        onContinueStory: (g) async {
          Navigator.pop(ctx);
          if (g) {
            showDialog(
              context: ctx,
              builder: (dialogCtx) => Dialog(
                insetPadding: EdgeInsets.zero,
                child: ConstrainedBox(
                  constraints: dialogConstraints(dialogCtx),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Padding(
                        padding:
                        const EdgeInsets.fromLTRB(24, 20, 24, 12),
                        child: Text('Continue Group Story',
                            textAlign: TextAlign.center,
                            style: Theme.of(dialogCtx).textTheme.titleLarge),
                      ),
                      const Divider(height: 1),
                      Expanded(
                        child: SingleChildScrollView(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 24, vertical: 16),
                          child: Text(
                            'Group stories are resumed by continuing a solo story and inviting a friend.',
                            style: Theme.of(dialogCtx).textTheme.bodyMedium,
                          ),
                        ),
                      ),
                      const Divider(height: 1),
                      Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 8),
                        child: Align(
                          alignment: Alignment.centerRight,
                          child: TextButton(
                            onPressed: () => Navigator.pop(dialogCtx),
                            child: const Text('OK'),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
            return;
          }
          await _resumeSolo(ctx);
        },
      ),
    );
  }

  /* ───────── build ───────── */

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final titleSize = min(width * 0.10, 80.0);
    final btnSize = min(width * 0.04, 20.0);
    final logoutSize = min(width * 0.03, 16.0);

    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Scaffold(
      body: Stack(
        children: [
          const DashboardBackground(),
          Center(
            child: SingleChildScrollView(
              child: Column(
                children: [
                  const SizedBox(height: 80),
                  Text(
                    'VersaTale',
                    textAlign: TextAlign.center,
                    style: tt.displayLarge?.copyWith(
                      fontSize: titleSize,
                      fontWeight: FontWeight.bold,
                      foreground: Paint()
                        ..style = PaintingStyle.stroke
                        ..strokeWidth = 2
                        ..color = Colors.white,
                      shadows: const [
                        Shadow(
                          offset: Offset(2, 2),
                          blurRadius: 3,
                          color: Colors.black26,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 40),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    alignment: WrapAlignment.center,
                    children: [
                      DashboardButton(
                          label: 'Story Archives',
                          onPressed: () => _toArchives(context),
                          fontSize: btnSize),
                      DashboardButton(
                          label: 'New Story',
                          onPressed: () => _storyOptions(context),
                          fontSize: btnSize),
                      DashboardButton(
                          label: 'Manage Profile',
                          onPressed: () => _toProfile(context),
                          fontSize: btnSize),
                      DashboardButton(
                          label: 'Join a Friend',
                          onPressed: () => _toJoin(context),
                          fontSize: btnSize),
                      DashboardButton(
                          label: 'Tutorial',
                          onPressed: () => openTutorialPdf(context),
                          fontSize: btnSize),
                    ],
                  ),
                  const SizedBox(height: 80),
                ],
              ),
            ),
          ),
          Positioned(
            top: 20,
            left: 16,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: cs.surface.withOpacity(.7),
                foregroundColor: cs.onSurface,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onPressed: () async {
                await AuthService().signOut();
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const MainSplashScreen(),
                  ),
                );
              },
              child: Text(
                'Log Out',
                style: tt.labelLarge?.copyWith(
                  fontSize: logoutSize,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
