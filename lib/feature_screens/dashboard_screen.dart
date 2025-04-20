// lib/screens/dashboard_screen.dart
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
import 'profile_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({Key? key}) : super(key: key);

  // ───────────────────── navigation helpers ──────────────────────
  void _navigateToProfile(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const ProfileScreen()),
    );
  }

  void _navigateToSavedStories(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const ViewStoriesScreen()),
    );
  }

  void _navigateToNewStoryWithMode(BuildContext context, bool isGroup) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CreateNewStoryScreen(isGroup: isGroup),
      ),
    );
  }

  Future<void> _navigateToActiveStoryWithMode(
      BuildContext context, bool isGroup) async {
    final storyService = StoryService();
    try {
      final active = await storyService.getActiveStory();
      if (active != null) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => StoryScreen(
              initialLeg : active['storyLeg']   ?? '',
              options    : List<String>.from(active['options'] ?? []),
              storyTitle : active['storyTitle'] ?? '',
            ),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('No active story found.', style: GoogleFonts.atma()),
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content:
          Text('Error resuming active story: $e', style: GoogleFonts.atma()),
        ),
      );
    }
  }

  void _navigateToJoinFriend(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const JoinMultiplayerScreen()),
    );
  }

  // ───────────────── dialog launcher ─────────────────────────────
  void _showStoryOptionsDialog(BuildContext ctx) {
    showDialog(
      context: ctx,
      builder: (_) => StoryOptionsDialog(
        onStartStory: (isGroup) async {
          Navigator.of(ctx).pop();                // close dialog
          await Future.delayed(Duration.zero);    // ← lets pop complete
          _navigateToNewStoryWithMode(ctx, isGroup);
        },
        onContinueStory: (isGroup) async {
          Navigator.of(ctx).pop();
          await Future.delayed(Duration.zero);    // ← fixes double‑tap issue
          _navigateToActiveStoryWithMode(ctx, isGroup);
        },
      ),
    );
  }

  // ─────────────────────── build ────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final w = constraints.maxWidth;
        final titleSize   = min(w * 0.10, 80.0);
        final buttonSize  = min(w * 0.04, 20.0);
        final logoutSize  = min(w * 0.03, 16.0);

        return Scaffold(
          body: Stack(
            children: [
              // background
              Positioned.fill(
                child: Container(
                  decoration: const BoxDecoration(
                    image: DecorationImage(
                      image: AssetImage('assets/versatale_dashboard2_image.png'),
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
              ),

              // main content
              Positioned.fill(
                child: SingleChildScrollView(
                  child: ConstrainedBox(
                    constraints:
                    BoxConstraints(minHeight: constraints.maxHeight),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const SizedBox(height: 80),
                        // title
                        Text(
                          'VersaTale',
                          style: GoogleFonts.atma(
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
                        // buttons
                        Wrap(
                          spacing: 10,
                          runSpacing: 10,
                          alignment: WrapAlignment.center,
                          children: [
                            _buildButton(
                              context,
                              'Story Archives',
                              onPressed: () => _navigateToSavedStories(context),
                              fontSize: buttonSize,
                            ),
                            _buildButton(
                              context,
                              'New Story',
                              onPressed: () => _showStoryOptionsDialog(context),
                              fontSize: buttonSize,
                            ),
                            _buildButton(
                              context,
                              'Manage Profile',
                              onPressed: () => _navigateToProfile(context),
                              fontSize: buttonSize,
                            ),
                            _buildButton(
                              context,
                              'Join a Friend',
                              onPressed: () => _navigateToJoinFriend(context),
                              fontSize: buttonSize,
                            ),
                          ],
                        ),
                        const SizedBox(height: 80),
                      ],
                    ),
                  ),
                ),
              ),

              // logout
              Positioned(
                top: 20,
                left: 16,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    backgroundColor: Colors.white.withOpacity(0.7),
                  ),
                  onPressed: () async {
                    await AuthService().signOut();
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(
                          builder: (_) => const MainSplashScreen()),
                    );
                  },
                  child: Text(
                    'Log Out',
                    style: GoogleFonts.atma(
                      fontSize: logoutSize,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF453E2C),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // helper to build translucent buttons
  Widget _buildButton(
      BuildContext context,
      String label, {
        required VoidCallback onPressed,
        required double fontSize,
      }) {
    return ElevatedButton(
      style: ElevatedButton.styleFrom(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        backgroundColor: Colors.white.withOpacity(0.7),
      ),
      onPressed: onPressed,
      child: Text(
        label,
        style: GoogleFonts.atma(
          fontSize: fontSize,
          fontWeight: FontWeight.bold,
          color: const Color(0xFF453E2C),
        ),
      ),
    );
  }
}

// ───────────────────────── dialog widget ────────────────────────

class StoryOptionsDialog extends StatefulWidget {
  const StoryOptionsDialog({
    Key? key,
    required this.onStartStory,
    required this.onContinueStory,
  }) : super(key: key);

  final Function(bool isGroup) onStartStory;
  final Function(bool isGroup) onContinueStory;

  @override
  State<StoryOptionsDialog> createState() => _StoryOptionsDialogState();
}

class _StoryOptionsDialogState extends State<StoryOptionsDialog> {
  bool _isGroup = false; // false => Solo, true => Group

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Story Options',
          style: GoogleFonts.atma(fontWeight: FontWeight.bold)),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            title: Text('Solo Story', style: GoogleFonts.atma()),
            leading: Radio<bool>(
              value: false,
              groupValue: _isGroup,
              onChanged: (val) => setState(() => _isGroup = val!),
            ),
          ),
          ListTile(
            title: Text('Group Story', style: GoogleFonts.atma()),
            leading: Radio<bool>(
              value: true,
              groupValue: _isGroup,
              onChanged: (val) => setState(() => _isGroup = val!),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text('Cancel', style: GoogleFonts.atma()),
        ),
        ElevatedButton(
          onPressed: () => widget.onStartStory(_isGroup),
          child: Text('Start Story', style: GoogleFonts.atma()),
        ),
        ElevatedButton(
          onPressed: () => widget.onContinueStory(_isGroup),
          child: Text('Continue Story', style: GoogleFonts.atma()),
        ),
      ],
    );
  }
}
