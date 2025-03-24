import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:versatale/screens/login_screen.dart';
import 'package:versatale/screens/create_new_story_screen.dart';
import 'package:versatale/screens/view_stories_screen.dart';
import 'package:versatale/screens/story_screen.dart';
import 'package:versatale/services/story_service.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({Key? key}) : super(key: key);

  void _navigateToProfile(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          "Manage Profile tapped",
          style: GoogleFonts.atma(),
        ),
      ),
    );
  }

  void _navigateToSavedStories(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => ViewStoriesScreen()),
    );
  }

  void _navigateToNewStory(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => CreateNewStoryScreen()),
    );
  }

  void _navigateToActiveStory(BuildContext context) async {
    final StoryService storyService = StoryService();
    try {
      final activeStory = await storyService.getActiveStory();
      print(activeStory);
      if (activeStory != null) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => StoryScreen(
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
          content: Text("Error resuming active story: $e",
              style: GoogleFonts.atma()),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // Background image container.
      body: Stack(
        children: [
          Container(
            decoration: BoxDecoration(
              image: DecorationImage(
                image:
                AssetImage("assets/versatale_dashboard2_image.png"),
                alignment: Alignment(-0.8, 0.0),
                fit: BoxFit.cover,
              ),
            ),
          ),
          // Log Out button in the bottom left.
          Positioned(
            bottom: 20,
            left: 16,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                padding:
                EdgeInsets.symmetric(horizontal: 20, vertical: 20),
                backgroundColor: Colors.white.withOpacity(0.7),
              ),
              onPressed: () {
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(
                      builder: (context) => LoginScreen()),
                );
              },
              child: Text(
                "Log Out",
                style: GoogleFonts.atma(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF453E2C),
                ),
              ),
            ),
          ),
          // Centered content.
          Center(
            child: Padding(
              padding:
              const EdgeInsets.symmetric(horizontal: 16.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // VersaTale text rendered with an outlined effect.
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      "VersaTale",
                      style: GoogleFonts.atma(
                        fontSize: 100,
                        fontWeight: FontWeight.bold,
                        foreground: Paint()
                          ..style = PaintingStyle.stroke
                          ..strokeWidth = 2
                          ..color = Colors.white,
                        shadows: [
                          Shadow(
                            offset: Offset(2.0, 2.0),
                            blurRadius: 3.0,
                            color: Colors.black26,
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 40),
                  // Wrap widget for responsive layout of buttons.
                  Wrap(
                    spacing: 20,
                    runSpacing: 20,
                    alignment: WrapAlignment.center,
                    children: [
                      _buildCircularButton(
                        context,
                        "Story Archives",
                            () => _navigateToSavedStories(context),
                      ),
                      _buildCircularButton(
                        context,
                        "Start Story",
                            () => _navigateToNewStory(context),
                      ),
                      _buildCircularButton(
                        context,
                        "Manage Profile",
                            () => _navigateToProfile(context),
                      ),
                      _buildCircularButton(
                        context,
                        "Continue Story",
                            () => _navigateToActiveStory(context),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCircularButton(BuildContext context, String label,
      VoidCallback onPressed) {
    return ElevatedButton(
      style: ElevatedButton.styleFrom(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        padding:
        EdgeInsets.symmetric(horizontal: 40, vertical: 20),
        backgroundColor: Colors.white.withOpacity(0.7),
      ),
      onPressed: onPressed,
      child: Text(
        label,
        style: GoogleFonts.atma(
          fontSize: 18,
          fontWeight: FontWeight.bold,
          color: const Color(0xFF453E2C),
        ),
      ),
    );
  }
}
