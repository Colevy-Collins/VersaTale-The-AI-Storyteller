import 'package:flutter/material.dart';
import 'package:versatale/screens/create_new_story_screen.dart';
import 'package:versatale/screens/view_stories_screen.dart';
import 'package:versatale/screens/story_screen.dart';
import 'package:versatale/services/story_service.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({Key? key}) : super(key: key);

  void _navigateToProfile(BuildContext context) {
    // TODO: Navigate to the Profile Management screen
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text("Manage Profile tapped")),
    );
  }

  void _navigateToSavedStories(BuildContext context) {
    // Navigate to the Saved Stories screen.
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => ViewStoriesScreen()),
    );
  }

  void _navigateToNewStory(BuildContext context) {
    // Navigate to the CreateNewStoryScreen.
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => CreateNewStoryScreen()),
    );
  }

  // New function to resume an active story.
  void _navigateToActiveStory(BuildContext context) async {
    final StoryService storyService = StoryService();
    try {
      // Assume getActiveStory() returns a Map containing keys:
      // "initialLeg", "options", and "storyTitle".
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
      appBar: AppBar(
        title: Text("Dashboard"),
        actions: [
          IconButton(
            icon: Icon(Icons.logout),
            onPressed: () {
              // TODO: Implement logout functionality
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text("Logout tapped")),
              );
            },
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Text(
              "Welcome to VersaTale Dashboard!",
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            SizedBox(height: 20),
            Expanded(
              child: ListView(
                children: [
                  ListTile(
                    leading: Icon(Icons.person),
                    title: Text("Manage Profile"),
                    trailing: Icon(Icons.arrow_forward_ios),
                    onTap: () => _navigateToProfile(context),
                  ),
                  Divider(),
                  ListTile(
                    leading: Icon(Icons.book),
                    title: Text("Saved Stories"),
                    trailing: Icon(Icons.arrow_forward_ios),
                    onTap: () => _navigateToSavedStories(context),
                  ),
                  Divider(),
                  // Resume Active Story button.
                  ListTile(
                    leading: Icon(Icons.play_arrow),
                    title: Text("Resume Active Story"),
                    trailing: Icon(Icons.arrow_forward_ios),
                    onTap: () => _navigateToActiveStory(context),
                  ),
                  Divider(),
                  ListTile(
                    leading: Icon(Icons.create),
                    title: Text("Create New Story"),
                    trailing: Icon(Icons.arrow_forward_ios),
                    onTap: () => _navigateToNewStory(context),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
