import 'dart:math';
import 'package:flutter/material.dart';
import '../services/story_service.dart';
import 'story_screen.dart';

class CreateNewStoryScreen extends StatefulWidget {
  const CreateNewStoryScreen({Key? key}) : super(key: key);

  @override
  _CreateNewStoryScreenState createState() => _CreateNewStoryScreenState();
}

class _CreateNewStoryScreenState extends State<CreateNewStoryScreen> {
  final StoryService storyService = StoryService();

  // Options for selection.
  final List<String> genres = ["Adventure", "Mystery", "Sci-Fi", "Fantasy"];
  final List<String> settings = ["Modern", "Historical", "Futuristic", "Medieval"];
  final List<String> tones = ["Lighthearted", "Dark", "Romantic", "Suspenseful"];

  // We'll use a constant value for maxLegs (target story length).
  final int maxLegs = 10;

  String? selectedGenre;
  String? selectedSetting;
  String? selectedTone;

  bool isLoading = false;

  @override
  void initState() {
    super.initState();
    // Set default values.
    selectedGenre = genres[0];
    selectedSetting = settings[0];
    selectedTone = tones[0];
  }

  // Randomize the selections.
  void randomizeSelection() {
    final random = Random();
    setState(() {
      selectedGenre = genres[random.nextInt(genres.length)];
      selectedSetting = settings[random.nextInt(settings.length)];
      selectedTone = tones[random.nextInt(tones.length)];
    });
  }

  // Starts the story by sending full options to the backend.
  // Here we use a default initial decision "Start Story".
  void startStory() async {
    if (selectedGenre == null || selectedSetting == null || selectedTone == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Please select a value for all fields.")),
      );
      return;
    }

    setState(() {
      isLoading = true;
    });

    try {
      // Use a default initial decision.
      final String initialDecision = "Start Story";
      final initialLeg = await storyService.startStory(
        decision: initialDecision,
        genre: selectedGenre!,
        setting: selectedSetting!,
        tone: selectedTone!,
        maxLegs: maxLegs,
      );
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => StoryScreen(initialLeg: initialLeg)),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error: $e")),
      );
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }

  // Helper widget to build dropdown fields.
  Widget buildDropdownField({
    required String label,
    required List<String> options,
    required String? value,
    required ValueChanged<String?> onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: Theme.of(context).textTheme.titleMedium),
        DropdownButton<String>(
          value: value,
          hint: Text("Choose $label"),
          isExpanded: true,
          items: options
              .map((option) => DropdownMenuItem(
            value: option,
            child: Text(option),
          ))
              .toList(),
          onChanged: onChanged,
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Create New Story"),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: isLoading
            ? Center(child: CircularProgressIndicator())
            : Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            buildDropdownField(
              label: "Genre",
              options: genres,
              value: selectedGenre,
              onChanged: (value) {
                setState(() {
                  selectedGenre = value;
                });
              },
            ),
            SizedBox(height: 20),
            buildDropdownField(
              label: "Setting",
              options: settings,
              value: selectedSetting,
              onChanged: (value) {
                setState(() {
                  selectedSetting = value;
                });
              },
            ),
            SizedBox(height: 20),
            buildDropdownField(
              label: "Tone & Style",
              options: tones,
              value: selectedTone,
              onChanged: (value) {
                setState(() {
                  selectedTone = value;
                });
              },
            ),
            SizedBox(height: 40),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                ElevatedButton(
                  onPressed: randomizeSelection,
                  child: Text("Randomize"),
                ),
                ElevatedButton(
                  onPressed: startStory,
                  child: Text("Start Story"),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
