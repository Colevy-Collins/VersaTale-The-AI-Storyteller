import 'dart:math';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'main_splash_screen.dart';
import 'create_new_story_screen.dart';
import 'view_stories_screen.dart';
import 'story_screen.dart';
import 'join_multiplayer_screen.dart';
import '../services/story_service.dart';
import '../services/auth_service.dart';
import 'profile_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({Key? key}) : super(key: key);

  void _navigateToProfile(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const ProfileScreen()),
    );
  }

  void _navigateToSavedStories(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const ViewStoriesScreen()),
    );
  }

  /// Navigate to the create story screen, passing `isGroup`.
  void _navigateToNewStoryWithMode(BuildContext context, bool isGroup) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CreateNewStoryScreen(isGroup: isGroup),
      ),
    );
  }

  /// Navigate to continue an active story, passing `isGroup`.
  void _navigateToActiveStoryWithMode(BuildContext context, bool isGroup) async {
    final storyService = StoryService();
    try {
      final activeStory = await storyService.getActiveStory();
      if (activeStory != null) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => StoryScreen(
              initialLeg: activeStory['storyLeg'] ?? "",
              options: List<String>.from(activeStory['options'] ?? []),
              storyTitle: activeStory["storyTitle"] ?? "",
            ),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              "No active story found.",
              style: GoogleFonts.atma(),
            ),
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            "Error resuming active story: $e",
            style: GoogleFonts.atma(),
          ),
        ),
      );
    }
  }

  /// Opens a dialog that prompts the user for story mode and action (start or continue).
  void _showStoryOptionsDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) {
        return StoryOptionsDialog(
          onStartStory: (isGroup) {
            Navigator.pop(context); // Close dialog
            _navigateToNewStoryWithMode(context, isGroup);
          },
          onContinueStory: (isGroup) {
            Navigator.pop(context); // Close dialog
            _navigateToActiveStoryWithMode(context, isGroup);
          },
        );
      },
    );
  }

  /// Navigate to the multiplayer join screen.
  void _navigateToJoinFriend(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const JoinMultiplayerScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final double screenWidth = constraints.maxWidth;
        final double titleFontSize = min(screenWidth * 0.10, 80.0);
        final double buttonFontSize = min(screenWidth * 0.04, 20.0);
        final double logoutFontSize = min(screenWidth * 0.03, 16.0);

        return Scaffold(
          body: Stack(
            children: [
              // Background image
              Positioned.fill(
                child: Container(
                  decoration: const BoxDecoration(
                    image: DecorationImage(
                      image: AssetImage("assets/versatale_dashboard2_image.png"),
                      fit: BoxFit.cover,
                      alignment: Alignment.center,
                    ),
                  ),
                ),
              ),

              // Main content
              Positioned.fill(
                child: SingleChildScrollView(
                  child: Container(
                    constraints: BoxConstraints(minHeight: constraints.maxHeight),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const SizedBox(height: 80),

                        // Title
                        Text(
                          "VersaTale",
                          style: GoogleFonts.atma(
                            fontSize: titleFontSize,
                            fontWeight: FontWeight.bold,
                            foreground: Paint()
                              ..style = PaintingStyle.stroke
                              ..strokeWidth = 2
                              ..color = Colors.white,
                            shadows: const [
                              Shadow(
                                offset: Offset(2.0, 2.0),
                                blurRadius: 3.0,
                                color: Colors.black26,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 40),

                        // Main menu buttons
                        Wrap(
                          spacing: 10,
                          runSpacing: 10,
                          alignment: WrapAlignment.center,
                          children: [
                            _buildButton(
                              context,
                              "Story Archives",
                              onPressed: () => _navigateToSavedStories(context),
                              fontSize: buttonFontSize,
                            ),
                            _buildButton(
                              context,
                              "Story Options",
                              onPressed: () => _showStoryOptionsDialog(context),
                              fontSize: buttonFontSize,
                            ),
                            _buildButton(
                              context,
                              "Manage Profile",
                              onPressed: () => _navigateToProfile(context),
                              fontSize: buttonFontSize,
                            ),
                            _buildButton(
                              context,
                              "Join a Friend",
                              onPressed: () => _navigateToJoinFriend(context),
                              fontSize: buttonFontSize,
                            ),
                          ],
                        ),

                        const SizedBox(height: 80),
                      ],
                    ),
                  ),
                ),
              ),

              // Logout button
              Positioned(
                top: 20,
                left: 16,
                child: ElevatedButton(
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
                    "Log Out",
                    style: GoogleFonts.atma(
                      fontSize: logoutFontSize,
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

  Widget _buildButton(
      BuildContext context,
      String label, {
        required VoidCallback onPressed,
        required double fontSize,
      }) {
    return ElevatedButton(
      style: ElevatedButton.styleFrom(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
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

/// Dialog for choosing Solo/Group, plus Start or Continue.
class StoryOptionsDialog extends StatefulWidget {
  final Function(bool isGroup) onStartStory;
  final Function(bool isGroup) onContinueStory;

  const StoryOptionsDialog({
    Key? key,
    required this.onStartStory,
    required this.onContinueStory,
  }) : super(key: key);

  @override
  _StoryOptionsDialogState createState() => _StoryOptionsDialogState();
}

class _StoryOptionsDialogState extends State<StoryOptionsDialog> {
  bool isGroup = false; // false => Solo, true => Group

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text("Story Options", style: GoogleFonts.atma(fontWeight: FontWeight.bold)),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            title: Text("Solo Story", style: GoogleFonts.atma()),
            leading: Radio<bool>(
              value: false,
              groupValue: isGroup,
              onChanged: (val) => setState(() => isGroup = val!),
            ),
          ),
          ListTile(
            title: Text("Group Story", style: GoogleFonts.atma()),
            leading: Radio<bool>(
              value: true,
              groupValue: isGroup,
              onChanged: (val) => setState(() => isGroup = val!),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text("Cancel", style: GoogleFonts.atma()),
        ),
        ElevatedButton(
          onPressed: () => widget.onStartStory(isGroup),
          child: Text("Start Story", style: GoogleFonts.atma()),
        ),
        ElevatedButton(
          onPressed: () => widget.onContinueStory(isGroup),
          child: Text("Continue Story", style: GoogleFonts.atma()),
        ),
      ],
    );
  }
}
