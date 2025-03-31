import 'dart:math';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

// Adjust these imports to match your project structure
import 'main_splash_screen.dart';
import 'create_new_story_screen.dart';
import 'view_stories_screen.dart';
import 'story_screen.dart';
import '../services/story_service.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({Key? key}) : super(key: key);

  void _navigateToProfile(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text("Manage Profile tapped", style: GoogleFonts.atma()),
      ),
    );
  }

  void _navigateToSavedStories(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const ViewStoriesScreen()),
    );
  }

  void _navigateToNewStory(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const CreateNewStoryScreen()),
    );
  }

  void _navigateToActiveStory(BuildContext context) async {
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
            content: Text("No active story found.", style: GoogleFonts.atma()),
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Error resuming active story: $e", style: GoogleFonts.atma()),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final double screenWidth = constraints.maxWidth;
        // Calculate dynamic font sizes based on screen width
        final double titleFontSize = min(screenWidth * 0.10, 80.0);
        final double buttonFontSize = min(screenWidth * 0.04, 20.0);
        final double logoutFontSize = min(screenWidth * 0.03, 16.0);

        return Scaffold(
          body: Stack(
            children: [
              // Background image, centered
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

              // "Log Out" button pinned at top-left
              Positioned(
                top: 20,
                left: 16,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    backgroundColor: Colors.white.withOpacity(0.7),
                  ),
                  onPressed: () {
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

              // Centered content (Title and main buttons)
              Positioned.fill(
                child: SingleChildScrollView(
                  child: Container(
                    constraints: BoxConstraints(minHeight: constraints.maxHeight),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const SizedBox(height: 80), // Top spacing

                        // Title text
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

                        // Wrap for main buttons (automatically wraps to new row when necessary)
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
                              "Start Story",
                              onPressed: () => _navigateToNewStory(context),
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
                              "Continue Story",
                              onPressed: () => _navigateToActiveStory(context),
                              fontSize: buttonFontSize,
                            ),
                          ],
                        ),

                        const SizedBox(height: 80), // Bottom spacing
                      ],
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

  // Helper method to build each button
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
