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
      SnackBar(content: Text("Manage Profile tapped")),
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
          SnackBar(content: Text("No active story found.")),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error resuming active story: $e")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Background image container
          Container(
            decoration: BoxDecoration(
              image: DecorationImage(
                image: AssetImage("assets/versatale_dashboard2_image.png"),
                alignment: Alignment(-0.8, 0.0),
                fit: BoxFit.cover,
              ),
            ),
          ),
          // Log Out button as an ElevatedButton in the bottom left
          Positioned(
            bottom: 20,
            left: 16,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: EdgeInsets.symmetric(horizontal: 20, vertical: 20),
                backgroundColor: Colors.white.withOpacity(0.5),
              ),
              onPressed: () {
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (context) => LoginScreen()),
                );
              },
              child: Text(
                "Log Out",
                style: GoogleFonts.atma(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                ),
              ),
            ),
          ),
          // Centered content with VersaTale text and button row underneath
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Centered VersaTale text with color #597a6f and shadow
                Text(
                  "VersaTale",
                  style: GoogleFonts.atma(
                    fontSize: 100,
                    fontWeight: FontWeight.bold,
                    color: Color(0xff3a5a50),
                    shadows: [
                      Shadow(
                        offset: Offset(2.0, 2.0),
                        blurRadius: 3.0,
                        color: Colors.black26,
                      ),
                    ],
                  ),
                ),
                SizedBox(height: 40),
                // Horizontal row of more transparent rectangular buttons
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _buildCircularButton(
                      context,
                      "Continue Story",
                          () => _navigateToSavedStories(context),
                    ),
                    SizedBox(width: 20),
                    _buildCircularButton(
                      context,
                      "Start Story",
                          () => _navigateToNewStory(context),
                    ),
                    SizedBox(width: 20),
                    _buildCircularButton(
                      context,
                      "Manage Profile",
                          () => _navigateToProfile(context),
                    ),
                    SizedBox(width: 20),
                    _buildCircularButton(
                      context,
                      "Resume Active Story",
                          () => _navigateToActiveStory(context),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCircularButton(BuildContext context, String label, VoidCallback onPressed) {
    return ElevatedButton(
      style: ElevatedButton.styleFrom(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        padding: EdgeInsets.symmetric(horizontal: 40, vertical: 20),
        backgroundColor: Colors.white.withOpacity(0.5),
      ),
      onPressed: onPressed,
      child: Text(
        label,
        style: GoogleFonts.atma(
          fontSize: 18,
          color: Colors.black,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}
