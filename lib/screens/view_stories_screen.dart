import 'dart:convert';
import 'dart:html' as html;
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
                // View/Download Story Button: Opens a dialog with story details and download option.
                ElevatedButton(
                  onPressed: () async {
                    try {
                      final storyDetails = await storyService.viewStory(
                          storyId: story["story_ID"]);
                      showDialog(
                        context: context,
                        builder: (context) {
                          return AlertDialog(
                            title: Text(storyDetails["storyTitle"] ?? "Story Details"),
                            content: SingleChildScrollView(
                              child: Text(
                                storyDetails["initialLeg"] ?? "No story content available.",
                              ),
                            ),
                            actions: [
                              // Download Story Button (placed beside the Close button)
                              ElevatedButton(
                                onPressed: () {
                                  try {
                                    // Reuse view data to generate file content.
                                    final content = storyDetails["initialLeg"] ??
                                        "No story content available.";
                                    final bytes = utf8.encode(content);
                                    final blob = html.Blob([bytes], 'text/plain');
                                    final url = html.Url.createObjectUrlFromBlob(blob);
                                    final anchor = html.document.createElement('a')
                                    as html.AnchorElement
                                      ..href = url
                                      ..download = "story_${story["storyTitle"]}.txt";
                                    html.document.body?.append(anchor);
                                    anchor.click();
                                    anchor.remove();
                                    html.Url.revokeObjectUrl(url);
                                  } catch (e) {
                                    print("Error downloading story: $e");
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(content: Text("Error downloading story: $e")),
                                    );
                                  }
                                },
                                child: const Text("Download Story"),
                              ),
                              const SizedBox(width: 16), // Extra space between buttons.
                              TextButton(
                                onPressed: () {
                                  Navigator.of(context).pop();
                                },
                                child: const Text("Close"),
                              ),
                            ],
                          );
                        },
                      );
                    } catch (e) {
                      print("Error viewing story: $e");
                    }
                  },
                  child: const Text("View/Download Story"),
                ),
                // Delete Story Button.
                ElevatedButton(
                  onPressed: () async {
                    try {
                      await storyService.deleteStory(storyId: story["story_ID"]);
                      fetchSavedStories();
                    } catch (e) {
                      print("Error deleting story: $e");
                    }
                  },
                  child: const Text("Delete Story"),
                ),
                // Continue Adventure Button.
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
                  child: const Text("Continue Adventure"),
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
        title: const Text("Saved Stories"),
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : errorMessage != null
          ? Center(child: Text("Error: $errorMessage"))
          : stories.isEmpty
          ? const Center(child: Text("No saved stories found."))
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
