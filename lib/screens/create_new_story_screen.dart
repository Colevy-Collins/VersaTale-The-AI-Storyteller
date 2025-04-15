import 'dart:math';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/dimension_map.dart'; // Now using groupedDimensionOptions
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

  // Maintain user selections for each dimension.
  final Map<String, String?> userSelections = {};

  // Remember the expansion state for each group.
  final Map<String, bool> groupExpansionState = {};

  // Dimensions that should be excluded from the UI (the system will pick these at random)
  final List<String> excludedDimensions = [
    "Decision Options",
    "Fail States",
    "Puzzle & Final Challenge",
    "Final Objective",
    "Protagonist Customization",
    "Moral Dilemmas",
    "Consequences of Failure"
  ];

  @override
  void initState() {
    super.initState();
    // Initialize all groups as collapsed.
    groupedDimensionOptions.forEach((groupName, _) {
      groupExpansionState[groupName] = false;
    });
  }

  /// Builds the grouped dimension UI.
  List<Widget> _buildGroupedDimensionWidgets(double baseFontSize) {
    List<Widget> groupWidgets = [];
    groupedDimensionOptions.forEach((groupName, dimensions) {
      if (dimensions is Map<String, dynamic>) {
        // Build the list of dropdowns for this group, filtering out excluded dimensions.
        List<Widget> dropdowns = _buildDimensionDropdownsForGroup(dimensions, baseFontSize);
        // If all children are excluded (dropdowns is empty), skip this group entirely.
        if (dropdowns.isEmpty) return;
        groupWidgets.add(
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8.0),
            child: Card(
              color: const Color(0xFFE7E6D9),
              elevation: 3,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: ExpansionTile(
                key: PageStorageKey<String>(groupName),
                title: Text(
                  groupName,
                  style: GoogleFonts.atma(
                    fontWeight: FontWeight.bold,
                    fontSize: baseFontSize + 2,
                  ),
                ),
                initiallyExpanded: groupExpansionState[groupName] ?? false,
                onExpansionChanged: (expanded) {
                  setState(() {
                    groupExpansionState[groupName] = expanded;
                  });
                },
                children: dropdowns,
              ),
            ),
          ),
        );
      }
    });
    return groupWidgets;
  }

  /// Builds dropdown widgets for each dimension in the given group.
  List<Widget> _buildDimensionDropdownsForGroup(dynamic dimensions, double baseFontSize) {
    List<Widget> dropdownWidgets = [];
    if (dimensions is Map<String, dynamic>) {
      dimensions.forEach((dimKey, dimValue) {
        // Skip this dimension if it is in the excludedDimensions list.
        if (excludedDimensions.contains(dimKey)) return;
        if (dimValue is List) {
          dropdownWidgets.add(
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
              child: DimensionDropdown(
                label: dimKey,
                options: List<String>.from(dimValue),
                initialValue: userSelections[dimKey],
                onChanged: (val) {
                  setState(() {
                    userSelections[dimKey] = val;
                  });
                },
              ),
            ),
          );
        }
      });
    }
    return dropdownWidgets;
  }

  /// Builds the payload for the backend.
  /// It iterates over all dimensions in the full map; for any dimension the user didn't set
  /// (including those excluded from the UI), a random option is chosen.
  Map<String, dynamic> buildDimensionSelectionData() {
    final data = <String, dynamic>{};

    groupedDimensionOptions.forEach((groupName, dimensions) {
      if (dimensions is Map<String, dynamic>) {
        dimensions.forEach((dimKey, dimValue) {
          if (dimValue is List) {
            final userChoice = userSelections[dimKey];
            List<String> options = List<String>.from(dimValue);
            data[dimKey] = userChoice ?? (options..shuffle()).first;
          }
        });
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
        SnackBar(content: Text("$e", style: GoogleFonts.atma())),
      );
    } finally {
      setState(() => isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (ctx, constraints) {
        final double screenWidth = constraints.maxWidth;
        final double baseFontSize = screenWidth < 400
            ? (screenWidth * 0.04).clamp(14.0, 18.0)
            : (screenWidth * 0.03).clamp(14.0, 20.0);

        return Scaffold(
          backgroundColor: const Color(0xFFC27B31),
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
                  // Insert the grouped dimension widgets.
                  ..._buildGroupedDimensionWidgets(baseFontSize),
                  SizedBox(height: baseFontSize * 1.2),
                  // Number of Options dropdown.
                  _buildLabeledCard(
                    "Number of Options:",
                    _buildOptionCountDropdown(baseFontSize),
                    baseFontSize,
                  ),
                  // Story Length dropdown.
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

  /// Helper method: a labeled card widget.
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
