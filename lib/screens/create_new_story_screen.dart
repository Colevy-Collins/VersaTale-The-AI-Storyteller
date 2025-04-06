import 'dart:math';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
// Dimensions & widgets from your project
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

  int selectedOptionCount = 2;        // 2, 3, or 4
  String selectedStoryLength = "Short"; // "Short", "Medium", "Long"

  // For saving user’s dropdown selections
  final Map<String, String?> userSelections = {};

  // Remember which expansion tiles are open/closed
  final Map<String, bool> expansionState = {};

  @override
  void initState() {
    super.initState();
    // Mark all expansions as initially collapsed
    dimensionDropdownOptions.forEach((dimKey, _) {
      expansionState[dimKey] = false;
    });
  }

  // Picks a random element from the given list if user left it as "Random"
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

    data["optionCount"] = selectedOptionCount;
    data["storyLength"] = selectedStoryLength;

    return data;
  }

  Future<void> startStory() async {
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
        SnackBar(
          content: Text("$e", style: GoogleFonts.atma()),
        ),
      );
    } finally {
      setState(() => isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (ctx, constraints) {
        // For smaller screens, scale text down
        final double screenWidth = constraints.maxWidth;
        final double baseFontSize = screenWidth < 400
            ? (screenWidth * 0.04).clamp(14.0, 18.0)
            : (screenWidth * 0.03).clamp(14.0, 20.0);

        // Dimensions we skip entirely
        final excludedDimensions = <String>[
          "Decision Options",
          "Fail States",
          "Puzzle & Final Challenge",
          "Final Objective",
          "Protagonist Customization",
          "Moral Dilemmas",
          "Consequences of Failure"
        ];

        // Create expansion cards for each dimension
        final dimensionWidgets = <Widget>[];
        dimensionDropdownOptions.forEach((dimKey, dimValue) {
          if (excludedDimensions.contains(dimKey)) return;

          dimensionWidgets.add(
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8.0),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 500),
                child: Card(
                  color: const Color(0xFFE7E6D9),
                  elevation: 3,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: _buildDimensionExpansionTile(
                    dimKey,
                    dimValue,
                    baseFontSize,
                  ),
                ),
              ),
            ),
          );
        });

        return Scaffold(
          backgroundColor: const Color(0xFFC27b31), // Warm background
          body: SafeArea(
            child: isLoading
                ? const Center(child: CircularProgressIndicator())
                : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.arrow_back),
                        color: Colors.white,
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                  SizedBox(height: baseFontSize),
                  Text(
                    "Create Your New Adventure",
                    textAlign: TextAlign.center,
                    style: GoogleFonts.atma(
                      fontSize: baseFontSize + 8,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  SizedBox(height: baseFontSize * 0.8),
                  Text(
                    "Select only the dimensions you care about.\nUnselected ones will be randomized.",
                    textAlign: TextAlign.center,
                    style: GoogleFonts.atma(
                      fontSize: baseFontSize,
                      color: Colors.white70,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  SizedBox(height: baseFontSize * 1.5),

                  // Dimension expansions
                  ...dimensionWidgets,

                  SizedBox(height: baseFontSize * 1.2),

                  // Number of Options
                  _buildLabeledCard(
                    "Number of Options:",
                    _buildOptionCountDropdown(baseFontSize),
                    baseFontSize,
                  ),

                  // Story Length
                  _buildLabeledCard(
                    "Story Length:",
                    _buildStoryLengthDropdown(baseFontSize),
                    baseFontSize,
                  ),
                  SizedBox(height: baseFontSize * 2),
                ],
              ),
            ),
          ),
          floatingActionButton: FloatingActionButton.extended(
            onPressed: startStory,
            label: Text(
              "Start Story",
              style: GoogleFonts.atma(
                color: Colors.black87,
                fontSize: baseFontSize,
                fontWeight: FontWeight.bold,
              ),
            ),
            backgroundColor: const Color(0xFFE7E6D9),
          ),
        );
      },
    );
  }

  /// A helper card that displays a label + widget (dropdown, etc.)
  Widget _buildLabeledCard(String label, Widget content, double baseFontSize) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 500),
        child: Card(
          color: const Color(0xFFE7E6D9),
          elevation: 3,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: GoogleFonts.atma(
                    fontSize: baseFontSize,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 8),
                content,
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Builds an ExpansionTile with dimension dropdown(s).
  Widget _buildDimensionExpansionTile(
      String dimKey,
      dynamic dimValue,
      double baseFontSize,
      ) {
    return ExpansionTile(
      key: PageStorageKey<String>(dimKey),
      title: Text(
        dimKey,
        style: GoogleFonts.atma(
          fontWeight: FontWeight.bold,
          fontSize: baseFontSize,
        ),
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
          child: _buildDimensionContent(dimKey, dimValue, baseFontSize),
        ),
      ],
    );
  }

  Widget _buildDimensionContent(
      String dimKey,
      dynamic dimValue,
      double baseFontSize,
      ) {
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

  Widget _buildOptionCountDropdown(double baseFontSize) {
    final options = [2, 3, 4];
    return DropdownButton<int>(
      value: selectedOptionCount,
      isExpanded: true,
      style: GoogleFonts.atma(
        fontSize: baseFontSize,
        color: Colors.black87,
        fontWeight: FontWeight.bold,
      ),
      items: options.map((count) {
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

  Widget _buildStoryLengthDropdown(double baseFontSize) {
    final lengthOptions = ["Short", "Medium", "Long"];
    return DropdownButton<String>(
      value: selectedStoryLength,
      isExpanded: true,
      style: GoogleFonts.atma(
        fontSize: baseFontSize,
        color: Colors.black87,
        fontWeight: FontWeight.bold,
      ),
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
