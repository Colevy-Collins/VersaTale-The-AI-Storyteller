import 'dart:math';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart'; // Ensure google_fonts is added to pubspec.yaml

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

  // userSelections[dimensionKey or "dimKey | subKey"] = user's choice or null
  final Map<String, String?> userSelections = {};

  // For controlling which dimension’s expansion tile is open
  final Map<String, bool> expansionState = {};

  @override
  void initState() {
    super.initState();
    // Initialize expansionState so that all dimensions are collapsed.
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
        final finalPick =
        resolveRandom(userChoice, List<String>.from(dimValue));
        data[dimKey] = finalPick;
      } else if (dimValue is Map<String, dynamic>) {
        final subData = <String, dynamic>{};
        dimValue.forEach((subKey, subValue) {
          if (subValue is List) {
            final mapKey = "$dimKey | $subKey";
            final subUserChoice = userSelections[mapKey];
            final finalPick =
            resolveRandom(subUserChoice, List<String>.from(subValue));
            subData[subKey] = finalPick;
          }
        });
        data[dimKey] = subData;
      }
    });

    // Also attach the user's chosen number of options and story length.
    data["optionCount"] = selectedOptionCount;
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
      const String initialDecision = "Start Story";

      final response = await storyService.startStory(
        decision: initialDecision,
        dimensionData: selectionData,
        maxLegs: maxLegs,
        optionCount: selectedOptionCount,
        storyLength: selectedStoryLength,
      );

      final String initialLeg = response["storyLeg"];
      final List<dynamic> initialOptionsDynamic = response["options"];
      final List<String> initialOptions =
      List<String>.from(initialOptionsDynamic);

      // Navigate to the next screen.
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
        SnackBar(
          content: Text("Error: $e", style: GoogleFonts.atma()),
        ),
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
    // List of dimension keys to exclude from the UI.
    final List<String> excludedDimensions = [
      "Decision Options",
      "Fail States",
      "Puzzle & Final Challenge",
      "Final Objective",
      "Protagonist Customization",
      "Moral Dilemmas",
      "Consequences of Failure"
    ];

    // Build a list of Widgets for dimensions, skipping any keys in the exclusion list.
    List<Widget> dimensionWidgets = [];
    for (var entry in dimensionDropdownOptions.entries) {
      if (excludedDimensions.contains(entry.key)) continue;
      dimensionWidgets.add(
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 12.0),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 500),
              child: Card(
                color: const Color(0xFFE7E6D9),
                elevation: 4,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: _buildDimensionExpansionTile(entry.key, entry.value),
              ),
            ),
          ),
        ),
      );
    }

    return Scaffold(
      // Background set to deep green (#527D4D)
      backgroundColor: const Color(0xFFC27b31),
      body: SafeArea(
        child: isLoading
            ? const Center(child: CircularProgressIndicator())
            : ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Custom back arrow.
            Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.arrow_back),
                  color: Colors.white,
                  onPressed: () {
                    Navigator.pop(context);
                  },
                ),
              ],
            ),
            const SizedBox(height: 16),
            // Primary heading in cursive (bold).
            Center(
              child: Text(
                "Create your new adventure",
                textAlign: TextAlign.center,
                style: GoogleFonts.atma(
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
            const SizedBox(height: 8),
            // Instruction subtitle in cursive (bold).
            Center(
              child: Text(
                "Please select which dimensions matter to you.\nAny dimensions left unselected will be randomized.",
                textAlign: TextAlign.center,
                style: GoogleFonts.atma(
                  fontSize: 18,
                  color: Colors.white70,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(height: 24),
            // Add dimension widgets built by the for loop.
            ...dimensionWidgets,
            const SizedBox(height: 20),
            // Option count wrapped in a Card.
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12.0),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 500),
                  child: Card(
                    color: const Color(0xFFE7E6D9),
                    elevation: 4,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "Number of Options:",
                            style: GoogleFonts.atma(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.black87,
                            ),
                          ),
                          const SizedBox(height: 8),
                          _buildOptionCountDropdown(),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),
            // Story length wrapped in a Card.
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12.0),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 500),
                  child: Card(
                    color: const Color(0xFFE7E6D9),
                    elevation: 4,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "Story Length:",
                            style: GoogleFonts.atma(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.black87,
                            ),
                          ),
                          const SizedBox(height: 8),
                          _buildStoryLengthDropdown(),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
      // Floating action button fixed at bottom right.
      floatingActionButton: FloatingActionButton.extended(
        onPressed: startStory,
        label: Text(
          "Start Story",
          style: GoogleFonts.atma(
            color: Colors.black87,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: const Color(0xFFE7E6D9),
      ),
    );
  }

  Widget _buildDimensionExpansionTile(String dimKey, dynamic dimValue) {
    return ExpansionTile(
      key: PageStorageKey<String>(dimKey), // Ensures stable expansion state.
      title: Text(
        dimKey,
        style: GoogleFonts.atma(fontWeight: FontWeight.bold),
      ),
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

  // Build the dropdown(s) inside the expansion tile.
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
          child: Text(
            count.toString(),
            style: GoogleFonts.atma(fontWeight: FontWeight.bold),
          ),
        );
      }).toList(),
      onChanged: (value) {
        setState(() {
          selectedOptionCount = value!;
        });
      },
      style: GoogleFonts.atma(fontSize: 16, color: Colors.black87, fontWeight: FontWeight.bold),
    );
  }

  // New dropdown for Story Length.
  Widget _buildStoryLengthDropdown() {
    final lengthOptions = ["Short", "Medium", "Long"];
    return DropdownButton<String>(
      value: selectedStoryLength,
      isExpanded: true,
      items: lengthOptions.map((length) {
        return DropdownMenuItem<String>(
          value: length,
          child: Text(
            length,
            style: GoogleFonts.atma(fontWeight: FontWeight.bold),
          ),
        );
      }).toList(),
      onChanged: (value) {
        setState(() {
          selectedStoryLength = value!;
        });
      },
      style: GoogleFonts.atma(fontSize: 16, color: Colors.black87, fontWeight: FontWeight.bold),
    );
  }
}
