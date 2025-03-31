import 'dart:convert';
import 'dart:html' as html;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart'; // For date formatting
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

  /// Formats the raw time string to a human-friendly format.
  /// If parsing fails, returns the raw string.
  String _formatTime(String rawTime) {
    try {
      DateTime dateTime = DateTime.parse(rawTime);
      // Example format: Jan 1, 2023 5:30 PM
      return DateFormat.yMMMd().add_jm().format(dateTime);
    } catch (e) {
      return rawTime;
    }
  }

  Widget buildStoryItem(Map<String, dynamic> story) {
    String storyTitle = story["storyTitle"] ?? "Untitled Story";
    // Format the time using _formatTime()
    String rawTime = story["lastActivity"] ?? "Unknown";
    String formattedTime = rawTime != "Unknown" ? _formatTime(rawTime) : rawTime;

    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      elevation: 4,
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ListTile(
              title: Text(
                storyTitle,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              subtitle: Text(
                formattedTime,
                style: const TextStyle(color: Colors.grey),
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              alignment: WrapAlignment.end,
              children: [
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
                              ElevatedButton(
                                onPressed: () {
                                  try {
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
                              const SizedBox(width: 8),
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
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text("Error viewing story: $e")),
                      );
                    }
                  },
                  child: Text("View/Download Story"),
                ),
                ElevatedButton(
                  onPressed: () async {
                    try {
                      await storyService.deleteStory(storyId: story["story_ID"]);
                      fetchSavedStories();
                    } catch (e) {
                      print("Error deleting story: $e");
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text("Error deleting story: $e")),
                      );
                    }
                  },
                  child: Text("Delete Story"),
                ),
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
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text("Error continuing adventure: $e")),
                      );
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
        title: Text(
          "Saved Stories",
          style: TextStyle(fontSize: 18),
        ),
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : errorMessage != null
          ? Center(child: Text("Error: $errorMessage", style: TextStyle(fontSize: 16)))
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
