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

  // Option count selection – this tells the backend how many options to generate.
  int selectedOptionCount = 2;

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
  // Receives a Map with "storyLeg" and "options", then passes them to StoryScreen.
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
      final response = await storyService.startStory(
        decision: initialDecision,
        genre: selectedGenre!,
        setting: selectedSetting!,
        tone: selectedTone!,
        maxLegs: maxLegs,
        optionCount: selectedOptionCount, // Send the desired option count to the backend.
      );
      print(response);
      final String initialLeg = response["storyLeg"];
      final List<dynamic> initialOptionsDynamic = response["options"];
      // Convert the dynamic list to List<String>
      final List<String> initialOptions = List<String>.from(initialOptionsDynamic);

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => StoryScreen(
            initialLeg: initialLeg,
            options: initialOptions,
            storyTitle: response["storyTitle"],
          ),
        ),
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

  // Helper widget to build dropdown fields for string selections.
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

  // Helper widget for option count (int) selection.
  Widget buildOptionCountDropdown() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text("Number of Options", style: Theme.of(context).textTheme.titleMedium),
        DropdownButton<int>(
          value: selectedOptionCount,
          isExpanded: true,
          items: [2, 3, 4]
              .map((count) => DropdownMenuItem<int>(
            value: count,
            child: Text(count.toString()),
          ))
              .toList(),
          onChanged: (value) {
            setState(() {
              selectedOptionCount = value!;
            });
          },
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
            SizedBox(height: 20),
            // Dropdown for selecting the number of options.
            buildOptionCountDropdown(),
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
