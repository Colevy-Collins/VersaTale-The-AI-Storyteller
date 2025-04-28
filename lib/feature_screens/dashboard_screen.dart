import 'dart:math';
import 'package:flutter/material.dart';

import 'login_screens/main_splash_screen.dart';
import 'new_story_screens/create_new_story_screen.dart';
import 'story_archives_screen.dart';
import 'story_screen.dart';
import 'mutiplayer_screens/join_multiplayer_screen.dart';
import '../services/story_service.dart';
import '../services/auth_service.dart';
import '../utils/ui_utils.dart';
import 'profile_screen.dart';

/// Home dashboard – start / continue stories, manage profile, etc.
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  /* ───────── navigation helpers ───────── */

  void _push(BuildContext c, Widget p) =>
      Navigator.push(c, MaterialPageRoute(builder: (_) => p));

  void _toProfile(BuildContext c)  => _push(c, const ProfileScreen());
  void _toArchives(BuildContext c) => _push(c, const StoryArchivesScreen());
  void _toNew(BuildContext c, {required bool group}) =>
      _push(c, CreateNewStoryScreen(isGroup: group));
  void _toJoin(BuildContext c)     => _push(c, const JoinMultiplayerScreen());

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
          initialLeg : active['storyLeg'] ?? '',
          options    : List<String>.from(active['options'] ?? []),
          storyTitle : active['storyTitle'] ?? '',
          inputTokens     : active['inputTokens']     ?? 0,
          outputTokens    : active['outputTokens']    ?? 0,
          estimatedCostUsd: active['estimatedCostUsd']?? 0.0,
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
              builder: (_) => AlertDialog(
                title   : const Text('Continue Group Story'),
                content : const Text(
                  'Group stories are resumed from the multiplayer lobby. '
                      'Invite others after continuing solo.',
                ),
                actions : [
                  TextButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: const Text('OK')),
                ],
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
    final width      = MediaQuery.of(context).size.width;
    final titleSize  = min(width * 0.10, 80.0);
    final btnSize    = min(width * 0.04, 20.0);
    final logoutSize = min(width * 0.03, 16.0);

    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Scaffold(
      body: Stack(
        children: [
          const _DashboardBackground(),
          Center(
            child: SingleChildScrollView(
              child: Column(
                children: [
                  const SizedBox(height: 80),
                  Text('VersaTale',
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
                              color: Colors.black26)
                        ],
                      )),
                  const SizedBox(height: 40),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    alignment: WrapAlignment.center,
                    children: [
                      _DashboardButton(
                          label: 'Story Archives',
                          onPressed: () => _toArchives(context),
                          fontSize: btnSize),
                      _DashboardButton(
                          label: 'New Story',
                          onPressed: () => _storyOptions(context),
                          fontSize: btnSize),
                      _DashboardButton(
                          label: 'Manage Profile',
                          onPressed: () => _toProfile(context),
                          fontSize: btnSize),
                      _DashboardButton(
                          label: 'Join a Friend',
                          onPressed: () => _toJoin(context),
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
                    borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: () async {
                await AuthService().signOut();
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(
                      builder: (_) => const MainSplashScreen()),
                );
              },
              child: Text('Log Out',
                  style: tt.labelLarge?.copyWith(
                    fontSize: logoutSize,
                    fontWeight: FontWeight.bold,
                  )),
            ),
          ),
        ],
      ),
    );
  }
}

/* ───────── reusable pieces ───────── */

class _DashboardBackground extends StatelessWidget {
  const _DashboardBackground();

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: DecoratedBox(
        decoration: const BoxDecoration(
          image: DecorationImage(
            image: AssetImage('assets/versatale_dashboard2_image.png'),
            fit: BoxFit.cover,
          ),
        ),
      ),
    );
  }
}

class _DashboardButton extends StatelessWidget {
  const _DashboardButton(
      {required this.label, required this.onPressed, required this.fontSize});

  final String label;
  final VoidCallback onPressed;
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return ElevatedButton(
      style: ElevatedButton.styleFrom(
        backgroundColor: cs.surface.withOpacity(.7),
        foregroundColor: cs.onSurface,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        shape:
        RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      onPressed: onPressed,
      child: Text(label,
          style: tt.labelLarge?.copyWith(
              fontSize: fontSize, fontWeight: FontWeight.bold)),
    );
  }
}

/* ───────── story options dialog ───────── */

class StoryOptionsDialog extends StatefulWidget {
  const StoryOptionsDialog(
      {super.key, required this.onStartStory, required this.onContinueStory});

  final void Function(bool group) onStartStory;
  final void Function(bool group) onContinueStory;

  @override
  State<StoryOptionsDialog> createState() => _StoryOptionsDialogState();
}

class _StoryOptionsDialogState extends State<StoryOptionsDialog> {
  bool _group = false;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;

    Widget tile(String title, bool value) => ListTile(
      title: Text(title, style: tt.bodyLarge),
      leading: Radio<bool>(
        value: value,
        groupValue: _group,
        onChanged: (v) => setState(() => _group = v ?? false),
      ),
    );

    return AlertDialog(
      title: Text('Story Options',
          style:
          tt.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          tile('Solo Story', false),
          tile('Group Story', true),
        ],
      ),
      actions: [
        TextButton(
          onPressed: Navigator.of(context).pop,
          child: Text('Cancel', style: tt.labelLarge),
        ),
        ElevatedButton(
          onPressed: () => widget.onStartStory(_group),
          style: ElevatedButton.styleFrom(
              backgroundColor: cs.primary,
              foregroundColor: cs.onPrimary),
          child: Text('Start Story', style: tt.labelLarge),
        ),
        ElevatedButton(
          onPressed: () => widget.onContinueStory(_group),
          style: ElevatedButton.styleFrom(
              backgroundColor: cs.secondary,
              foregroundColor: cs.onSecondary),
          child: Text('Continue Story', style: tt.labelLarge),
        ),
      ],
    );
  }
}