import 'package:flutter/material.dart';
import 'package:versatale/screens/create_new_story_screen.dart';


class HomeScreen extends StatelessWidget {
  const HomeScreen({Key? key}) : super(key: key);

  void _navigateToProfile(BuildContext context) {
    // TODO: Navigate to the Profile Management screen
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text("Manage Profile tapped")),
    );
  }

  void _navigateToSavedStories(BuildContext context) {
    // TODO: Navigate to the Saved Stories screen
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text("Saved Stories tapped")),
    );
  }

  void _navigateToNewStory(BuildContext context) {
    // Navigate to the CreateNewStoryScreen
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => CreateNewStoryScreen()),
    );
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