import 'dart:math';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'login_screens/main_splash_screen.dart';
import 'new_story_screens/create_new_story_screen.dart';
import 'story_archives_screen.dart';
import 'story_screen.dart';
import 'mutiplayer_screens/join_multiplayer_screen.dart';
import '../services/story_service.dart';
import '../services/auth_service.dart';
import '../utils/ui_utils.dart'; // Utility functions for snackbars and dialogs
import 'profile_screen.dart';

/// Dashboard / home screen that lets the user start a new story,
/// resume a solo story or join / manage multiplayer sessions.
///
/// The widget is intentionally kept *stateless*; all async work is
/// triggered in callbacks. This keeps build() cheap and free from
/// side‑effects.
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  // ────────────────── Navigation helpers ──────────────────

  void _push(BuildContext context, Widget page) =>
      Navigator.push(context, MaterialPageRoute(builder: (_) => page));

  void _navigateToProfile(BuildContext ctx) => _push(ctx, const ProfileScreen());

  void _navigateToSavedStories(BuildContext ctx) =>
      _push(ctx, const ViewStoriesScreen());

  void _navigateToNewStory(BuildContext ctx, {required bool isGroup}) =>
      _push(ctx, CreateNewStoryScreen(isGroup: isGroup));

  /// Attempts to resume a solo story, showing a snack or error dialog
  Future<void> _resumeSoloStory(BuildContext ctx) async {
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
        ),
      );
    } catch (e) {
      showError(ctx, 'Error resuming active story: $e');
    }
  }

  void _navigateToJoinFriend(BuildContext ctx) =>
      _push(ctx, const JoinMultiplayerScreen());

  // ────────────── Dialog launchers ──────────────

  /// Explains to the user that group stories must be continued from the
  /// multiplayer lobby instead of the dashboard.
  void _showGroupContinueInfoDialog(BuildContext ctx) {
    showDialog(
      context: ctx,
      builder: (_) => AlertDialog(
        title: Text('Continue Group Story', style: GoogleFonts.kottaOne()),
        content: Text(
          'Group stories are resumed from continuing the story in solo and inviting others.',
            style: GoogleFonts.kottaOne(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('OK', style: GoogleFonts.kottaOne(),),
          ),
        ],
      ),
    );
  }

  void _showStoryOptionsDialog(BuildContext ctx) {
    showDialog(
      context: ctx,
      builder: (_) => StoryOptionsDialog(
        onStartStory: (isGroup) {
          Navigator.pop(ctx); // close dialog
          _navigateToNewStory(ctx, isGroup: isGroup);
        },
        onContinueStory: (isGroup) async {
          Navigator.pop(ctx);

          // Group → show explanation dialog
          if (isGroup) {
            _showGroupContinueInfoDialog(ctx);
            return;
          }

          // Solo → attempt to resume, only if one exists
          await _resumeSoloStory(ctx);
        },
      ),
    );
  }

  // ─────────────────────── build ──────────────────────
  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (ctx, constraints) {
        final w = constraints.maxWidth;
        final titleSize = min(w * 0.10, 80.0);
        final buttonSize = min(w * 0.04, 20.0);
        final logoutSize = min(w * 0.03, 16.0);

        return Scaffold(
          body: Stack(
            children: [
              const _DashboardBackground(),
              Center(
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const SizedBox(height: 80),
                      _AppTitle(fontSize: titleSize),
                      const SizedBox(height: 40),
                      Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        alignment: WrapAlignment.center,
                        children: [
                          _DashboardButton(
                            label: 'Story Archives',
                            onPressed: () => _navigateToSavedStories(ctx),
                            fontSize: buttonSize,
                          ),
                          _DashboardButton(
                            label: 'New Story',
                            onPressed: () => _showStoryOptionsDialog(ctx),
                            fontSize: buttonSize,
                          ),
                          _DashboardButton(
                            label: 'Manage Profile',
                            onPressed: () => _navigateToProfile(ctx),
                            fontSize: buttonSize,
                          ),
                          _DashboardButton(
                            label: 'Join a Friend',
                            onPressed: () => _navigateToJoinFriend(ctx),
                            fontSize: buttonSize,
                          ),
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
                child: _LogoutButton(fontSize: logoutSize),
              ),
            ],
          ),
        );
      },
    );
  }
}

// ────────────────────  Reusable UI pieces  ─────────────────────

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

class _AppTitle extends StatelessWidget {
  const _AppTitle({required this.fontSize});

  final double fontSize;

  @override
  Widget build(BuildContext context) {
    return Text(
      'VersaTale',
      style: GoogleFonts.kottaOne(
        fontSize: fontSize,
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
      textAlign: TextAlign.center,
    );
  }
}

class _DashboardButton extends StatelessWidget {
  const _DashboardButton({
    required this.label,
    required this.onPressed,
    required this.fontSize,
  });

  final String label;
  final VoidCallback onPressed;
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      style: ElevatedButton.styleFrom(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        backgroundColor: Colors.white.withOpacity(0.7),
      ),
      onPressed: onPressed,
      child: Text(
        label,
        style: GoogleFonts.kottaOne(
          fontSize: fontSize,
          fontWeight: FontWeight.bold,
          color: const Color(0xFF453E2C),
        ),
      ),
    );
  }
}

class _LogoutButton extends StatelessWidget {
  const _LogoutButton({required this.fontSize});

  final double fontSize;

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      style: ElevatedButton.styleFrom(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        backgroundColor: Colors.white.withOpacity(0.7),
      ),
      onPressed: () async {
        await AuthService().signOut();
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const MainSplashScreen()),
        );
      },
      child: Text(
        'Log Out',
        style: GoogleFonts.kottaOne(
          fontSize: fontSize,
          fontWeight: FontWeight.bold,
          color: const Color(0xFF453E2C),
        ),
      ),
    );
  }
}

// ────────────────── Story Options Dialog ────────────────────

class StoryOptionsDialog extends StatefulWidget {
  const StoryOptionsDialog({
    super.key,
    required this.onStartStory,
    required this.onContinueStory,
  });

  final void Function(bool isGroup) onStartStory;
  final void Function(bool isGroup) onContinueStory;

  @override
  State<StoryOptionsDialog> createState() => _StoryOptionsDialogState();
}

class _StoryOptionsDialogState extends State<StoryOptionsDialog> {
  bool _isGroup = false; // false = solo

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Story Options', style: GoogleFonts.kottaOne(fontWeight: FontWeight.bold)),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _storyTypeTile('Solo Story', isGroup: false),
          _storyTypeTile('Group Story', isGroup: true),
        ],
      ),
      actions: [
        TextButton(
          onPressed: Navigator.of(context).pop,
          child: Text('Cancel', style: GoogleFonts.kottaOne()),
        ),
        ElevatedButton(
          onPressed: () => widget.onStartStory(_isGroup),
          child: Text('Start Story', style: GoogleFonts.kottaOne()),
        ),
        ElevatedButton(
          onPressed: () => widget.onContinueStory(_isGroup),
          child: Text('Continue Story', style: GoogleFonts.kottaOne()),
        ),
      ],
    );
  }

  Widget _storyTypeTile(String title, {required bool isGroup}) {
    return ListTile(
      title: Text(title, style: GoogleFonts.kottaOne()),
      leading: Radio<bool>(
        value: isGroup,
        groupValue: _isGroup,
        onChanged: (value) => setState(() => _isGroup = value ?? false),
      ),
    );
  }
}
