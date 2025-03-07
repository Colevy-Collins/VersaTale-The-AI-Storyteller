import 'package:flutter/material.dart';
import '../services/story_service.dart';

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
    // Customize this widget based on your story data.
    String storyTitle = story["storyTitle"] ?? "Untitled Story";
    String createdAt = story["createdAt"] ?? "Unknown date";
    return Card(
      child: ListTile(
        title: Text(storyTitle),
        subtitle: Text(story["lastActivity"] ?? "Unknown"),
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
