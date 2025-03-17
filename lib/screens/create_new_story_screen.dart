import 'dart:math';
import 'package:flutter/material.dart';

// 1) Import your dimension map and dropdown widget
import '../services/dimension_map.dart';
import '../widgets/dimension_dropdown.dart';
import '../services/story_service.dart';
import 'story_screen.dart';

class CreateNewStoryScreen extends StatefulWidget {
  const CreateNewStoryScreen({Key? key}) : super(key: key);

  @override
  _CreateNewStoryScreenState createState() => _CreateNewStoryScreenState();
}

class _CreateNewStoryScreenState extends State<CreateNewStoryScreen> {
  final StoryService storyService = StoryService();
  final int maxLegs = 10;

  bool isLoading = false;

  // The user can set how many options appear at each decision point
  int selectedOptionCount = 2;

  // "Story Length" selection (Short, Medium, Long, etc.)
  String selectedStoryLength = "Short";

  // userSelections[dimensionKey or "dimKey | subKey"] = user’s choice or null
  final Map<String, String?> userSelections = {};

  // For controlling which dimension’s expansion tile is open
  final Map<String, bool> expansionState = {};

  @override
  void initState() {
    super.initState();
    // Initialize expansionState so everything is collapsed
    dimensionDropdownOptions.forEach((dimKey, dimValue) {
      expansionState[dimKey] = false;
    });
  }

  // ----------------------------------
  //  Random picking
  // ----------------------------------

  String resolveRandom(String? userChoice, List<String> options) {
    if (userChoice == null || userChoice == "Random") {
      return pickRandomFromList(options);
    }
    return userChoice;
  }

  String pickRandomFromList(List<String> options) {
    if (options.isEmpty) return "Unknown";
    final rand = Random();
    return options[rand.nextInt(options.length)];
  }

  // ----------------------------------
  //  Build final dimension data
  // ----------------------------------

  Map<String, dynamic> buildDimensionSelectionData() {
    final data = <String, dynamic>{};

    dimensionDropdownOptions.forEach((dimKey, dimValue) {
      if (dimValue is List) {
        final userChoice = userSelections[dimKey];
        final finalPick = resolveRandom(userChoice, List<String>.from(dimValue));
        data[dimKey] = finalPick;
      } else if (dimValue is Map<String, dynamic>) {
        final subData = <String, dynamic>{};
        dimValue.forEach((subKey, subValue) {
          if (subValue is List) {
            final mapKey = "$dimKey | $subKey";
            final subUserChoice = userSelections[mapKey];
            final finalPick = resolveRandom(subUserChoice, List<String>.from(subValue));
            subData[subKey] = finalPick;
          }
        });
        data[dimKey] = subData;
      }
    });

    // Also attach the user’s chosen number of options
    data["optionCount"] = selectedOptionCount;

    // Attach the user’s selected story length
    data["storyLength"] = selectedStoryLength;

    return data;
  }

  // ----------------------------------
  //  Start story
  // ----------------------------------

  void startStory() async {
    setState(() => isLoading = true);

    try {
      final selectionData = buildDimensionSelectionData();
      final String initialDecision = "Start Story";

      final response = await storyService.startStory(
        decision: initialDecision,
        dimensionData: selectionData,
        maxLegs: maxLegs,
        optionCount: selectedOptionCount,
        storyLength: selectedStoryLength,
      );

      final String initialLeg = response["storyLeg"];
      final List<dynamic> initialOptionsDynamic = response["options"];
      final List<String> initialOptions = List<String>.from(initialOptionsDynamic);

      // Navigate to the next screen
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
      setState(() => isLoading = false);
    }
  }

  // ----------------------------------
  //  Building the UI
  // ----------------------------------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Create New Story")),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Possibly show instructions at the top
          Text(
            "Select only the dimensions you care about.\n"
                "Everything else will be randomized!",
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 16),

          // One expansion tile per dimension
          ...dimensionDropdownOptions.entries.map((entry) {
            final dimKey = entry.key;
            final dimValue = entry.value;
            return _buildDimensionExpansionTile(dimKey, dimValue);
          }).toList(),
          const SizedBox(height: 20),

          // Option count
          Text("Number of Options:", style: Theme.of(context).textTheme.titleMedium),
          _buildOptionCountDropdown(),
          const SizedBox(height: 20),

          // Story length
          Text("Story Length:", style: Theme.of(context).textTheme.titleMedium),
          _buildStoryLengthDropdown(),
          const SizedBox(height: 30),

          // Start Story button
          Align(
            alignment: Alignment.centerRight,
            child: ElevatedButton(
              onPressed: startStory,
              child: const Text("Start Story"),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDimensionExpansionTile(String dimKey, dynamic dimValue) {
    return ExpansionTile(
      key: PageStorageKey<String>(dimKey), // ensures stable expansion state
      title: Text(dimKey),
      initiallyExpanded: expansionState[dimKey] ?? false,
      onExpansionChanged: (expanded) {
        setState(() {
          expansionState[dimKey] = expanded;
        });
      },
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 16, right: 16, bottom: 16),
          child: _buildDimensionContent(dimKey, dimValue),
        ),
      ],
    );
  }

  // Build the actual dropdown(s) inside the expanded area
  Widget _buildDimensionContent(String dimKey, dynamic dimValue) {
    if (dimValue is List) {
      return DimensionDropdown(
        label: dimKey,
        options: List<String>.from(dimValue),
        initialValue: userSelections[dimKey],
        onChanged: (val) {
          setState(() {
            userSelections[dimKey] = val;
          });
        },
      );
    } else if (dimValue is Map<String, dynamic>) {
      final subWidgets = <Widget>[];
      dimValue.forEach((subKey, subValue) {
        if (subValue is List) {
          final mapKey = "$dimKey | $subKey";
          subWidgets.add(
            DimensionDropdown(
              label: subKey,
              options: List<String>.from(subValue),
              initialValue: userSelections[mapKey],
              onChanged: (val) {
                setState(() {
                  userSelections[mapKey] = val;
                });
              },
            ),
          );
          subWidgets.add(const SizedBox(height: 16));
        }
      });
      return Column(children: subWidgets);
    }
    return const SizedBox.shrink();
  }

  Widget _buildOptionCountDropdown() {
    return DropdownButton<int>(
      value: selectedOptionCount,
      isExpanded: true,
      items: [2, 3, 4].map((count) {
        return DropdownMenuItem<int>(
          value: count,
          child: Text(count.toString()),
        );
      }).toList(),
      onChanged: (value) {
        setState(() {
          selectedOptionCount = value!;
        });
      },
    );
  }

  // New dropdown for Story Length
  Widget _buildStoryLengthDropdown() {
    // Example choices for length
    final lengthOptions = ["Short", "Medium", "Long"];

    return DropdownButton<String>(
      value: selectedStoryLength,
      isExpanded: true,
      items: lengthOptions.map((length) {
        return DropdownMenuItem<String>(
          value: length,
          child: Text(length),
        );
      }).toList(),
      onChanged: (value) {
        setState(() {
          selectedStoryLength = value!;
        });
      },
    );
  }
}
