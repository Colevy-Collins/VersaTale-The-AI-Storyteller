import 'package:flutter/material.dart';
import '../services/story_service.dart';
import 'story_screen.dart';

class ViewStoriesScreen extends StatefulWidget {
  const ViewStoriesScreen({Key? key}) : super(key: key);

  @override
  _ViewStoriesScreenState createState() => _ViewStoriesScreenState();
}

class _ViewStoriesScreenState extends State<ViewStoriesScreen> {
  final StoryService storyService = StoryService();
  List<dynamic> stories = [];
  bool isLoading = false;
  String? errorMessage;

  @override
  void initState() {
    super.initState();
    fetchSavedStories();
  }

  Future<void> fetchSavedStories() async {
    setState(() {
      isLoading = true;
      errorMessage = null;
    });
    try {
      final List<dynamic> fetchedStories = await storyService.getSavedStories();
      setState(() {
        stories = fetchedStories;
      });
    } catch (e) {
      setState(() {
        errorMessage = e.toString();
      });
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }

  Widget buildStoryItem(Map<String, dynamic> story) {
    String storyTitle = story["storyTitle"] ?? "Untitled Story";
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ListTile(
              title: Text(storyTitle),
              subtitle: Text(story["lastActivity"] ?? "Unknown"),
            ),
            ButtonBar(
              alignment: MainAxisAlignment.end,
              children: [
                // View Story Button: Opens a dialog with story details.
                ElevatedButton(
                  onPressed: () async {
                    try {
                      final storyDetails =
                      await storyService.viewStory(storyId: story["story_ID"]);
                      showDialog(
                        context: context,
                        builder: (context) {
                          return AlertDialog(
                            title: Text(storyDetails["storyTitle"] ?? "Story Details"),
                            content: SingleChildScrollView(
                              child: Text(
                                  storyDetails["initialLeg"] ?? "No story content available."),
                            ),
                            actions: [
                              TextButton(
                                onPressed: () {
                                  Navigator.of(context).pop();
                                },
                                child: Text("Close"),
                              ),
                            ],
                          );
                        },
                      );
                    } catch (e) {
                      print("Error viewing story: $e");
                    }
                  },
                  child: Text("View Story"),
                ),
                // Delete Story Button: Calls delete endpoint and refreshes list.
                ElevatedButton(
                  onPressed: () async {
                    try {
                      await storyService.deleteStory(storyId: story["story_ID"]);
                      fetchSavedStories();
                    } catch (e) {
                      print("Error deleting story: $e");
                    }
                  },
                  child: Text("Delete Story"),
                ),
                // Continue Adventure Button: Loads the saved story into memory and navigates to StoryScreen.
                ElevatedButton(
                  onPressed: () async {
                    try {
                      final continuation =
                      await storyService.continueStory(storyId: story["story_ID"]);
                      final String storyLeg = continuation["storyLeg"];
                      final List<dynamic> optionsDynamic = continuation["options"];
                      final List<String> options = List<String>.from(optionsDynamic);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => StoryScreen(
                            initialLeg: storyLeg,
                            options: options,
                            storyTitle: continuation["storyTitle"],
                          ),
                        ),
                      );
                    } catch (e) {
                      print("Error continuing adventure: $e");
                    }
                  },
                  child: Text("Continue Adventure"),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Saved Stories"),
      ),
      body: isLoading
          ? Center(child: CircularProgressIndicator())
          : errorMessage != null
          ? Center(child: Text("Error: $errorMessage"))
          : stories.isEmpty
          ? Center(child: Text("No saved stories found."))
          : RefreshIndicator(
        onRefresh: fetchSavedStories,
        child: ListView.builder(
          itemCount: stories.length,
          itemBuilder: (context, index) {
            return buildStoryItem(stories[index] as Map<String, dynamic>);
          },
        ),
      ),
    );
  }
}
