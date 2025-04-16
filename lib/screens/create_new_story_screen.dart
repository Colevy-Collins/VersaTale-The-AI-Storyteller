import 'dart:math';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

// Suppose you have a dimension_map.dart that defines groupedDimensionOptions
import '../services/dimension_map.dart'; // Contains your groupedDimensionOptions JSON.
import '../widgets/dimension_dropdown.dart';
import '../services/story_service.dart';
import 'story_screen.dart';
import 'multiplayer_host_lobby_screen.dart';

class CreateNewStoryScreen extends StatefulWidget {
  final bool isGroup; // Determines if we're creating a group (multiplayer) story

  const CreateNewStoryScreen({Key? key, required this.isGroup}) : super(key: key);

  @override
  _CreateNewStoryScreenState createState() => _CreateNewStoryScreenState();
}

class _CreateNewStoryScreenState extends State<CreateNewStoryScreen> {
  final StoryService storyService = StoryService();

  bool isLoading = false;
  int maxLegs = 10;

  int selectedOptionCount = 2;       // 2,3,4
  String selectedStoryLength = "Short"; // "Short", "Medium", "Long"

  // Tracks user dropdown selections (dimensionKey -> userChoice)
  final Map<String, String?> userSelections = {};
  // Remember which dimension groups are expanded
  final Map<String, bool> expansionState = {};

  // Groups we skip entirely
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
    // Initialize each group in groupedDimensionOptions as collapsed
    groupedDimensionOptions.forEach((groupName, _) {
      expansionState[groupName] = false;
    });
  }

  /// Build dimension UI for each group
  List<Widget> _buildGroupedDimensionWidgets(double baseFontSize) {
    List<Widget> groupWidgets = [];
    groupedDimensionOptions.forEach((groupName, dimensions) {
      if (excludedDimensions.contains(groupName)) return;
      if (dimensions is Map<String, dynamic>) {
        final dropdowns = _buildDimensionDropdownsForGroup(dimensions, baseFontSize);
        if (dropdowns.isEmpty) return;
        groupWidgets.add(
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8.0),
            child: Card(
              color: const Color(0xFFE7E6D9),
              elevation: 3,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: ExpansionTile(
                key: PageStorageKey<String>(groupName),
                title: Text(
                  groupName,
                  style: GoogleFonts.atma(fontWeight: FontWeight.bold, fontSize: baseFontSize + 2),
                ),
                initiallyExpanded: expansionState[groupName] ?? false,
                onExpansionChanged: (expanded) => setState(() { expansionState[groupName] = expanded; }),
                children: dropdowns,
              ),
            ),
          ),
        );
      }
    });
    return groupWidgets;
  }

  /// Build dimension dropdowns for each dimension within a group
  List<Widget> _buildDimensionDropdownsForGroup(Map<String, dynamic> dimensions, double baseFontSize) {
    List<Widget> dropdownWidgets = [];
    dimensions.forEach((dimKey, dimValue) {
      if (excludedDimensions.contains(dimKey)) return;
      if (dimValue is List) {
        dropdownWidgets.add(
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: DimensionDropdown(
              label: dimKey,
              options: List<String>.from(dimValue),
              initialValue: userSelections[dimKey],
              onChanged: (val) => setState(() {
                userSelections[dimKey] = val;
              }),
            ),
          ),
        );
      }
    });
    return dropdownWidgets;
  }

  /// Builds dimension payload (dimensionKey -> userChoice or random)
  Map<String, dynamic> buildDimensionSelectionData() {
    final data = <String, dynamic>{};
    groupedDimensionOptions.forEach((_, groupValues) {
      if (groupValues is Map<String, dynamic>) {
        groupValues.forEach((dimKey, dimValue) {
          if (dimValue is List) {
            final userChoice = userSelections[dimKey];
            final options = List<String>.from(dimValue);
            // If no user choice, pick a random element
            data[dimKey] = userChoice ?? (options..shuffle()).first;
          }
        });
      }
    });
    data["optionCount"] = selectedOptionCount;
    data["storyLength"] = selectedStoryLength;
    return data;
  }

  /// For vote: only the explicitly chosen dimensions
  Map<String, String> buildVoteData() {
    final vote = <String, String>{};
    userSelections.forEach((dimKey, val) {
      if (val != null) vote[dimKey] = val;
    });
    return vote;
  }

  /// Start a SOLO story
  Future<void> startSoloStory() async {
    setState(() => isLoading = true);
    try {
      final dims = buildDimensionSelectionData();
      final response = await storyService.startStory(
        decision: "Start Story",
        dimensionData: dims,
        maxLegs: maxLegs,
        optionCount: selectedOptionCount,
        storyLength: selectedStoryLength,
      );
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => StoryScreen(
            initialLeg: response["storyLeg"],
            options: List<String>.from(response["options"]),
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

  /// Start a GROUP story and navigate to the host lobby
  Future<void> startGroupStory() async {
    setState(() => isLoading = true);
    try {
      final payload = {
        "decision": "Start Story",
        // "dimensions": dims, etc...
      };

      final result = await storyService.startGroupStory(payload);
      // result = { "sessionId", "joinCode", "storyState", "players" }

      final players = Map<String, dynamic>.from(result["players"] ?? {});
      // Convert string keys to int
      final parsedPlayers = players.map((slotStr, info) {
        final slot = int.parse(slotStr);
        return MapEntry(slot, Map<String, dynamic>.from(info));
      });

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => MultiplayerHostLobbyScreen(
            dimensionData:     result["storyState"]["dimensions"] ?? {},
            sessionId:         result["sessionId"],
            joinCode:          result["joinCode"],
            playersMap:        parsedPlayers,
          ),
        ),
      );
    } catch (e) {
      // handle error
    } finally {
      setState(() => isLoading = false);
    }
  }

  Widget _buildOptionCountDropdown(double baseFontSize) {
    final options = [2, 3, 4];
    return DropdownButton<int>(
      value: selectedOptionCount,
      isExpanded: true,
      style: GoogleFonts.atma(
          fontSize: baseFontSize, color: Colors.black87, fontWeight: FontWeight.bold
      ),
      items: options.map((count) {
        return DropdownMenuItem<int>(
          value: count,
          child: Text(count.toString()),
        );
      }).toList(),
      onChanged: (value) {
        setState(() => selectedOptionCount = value!);
      },
    );
  }

  Widget _buildStoryLengthDropdown(double baseFontSize) {
    final lengthOptions = ["Short", "Medium", "Long"];
    return DropdownButton<String>(
      value: selectedStoryLength,
      isExpanded: true,
      style: GoogleFonts.atma(
          fontSize: baseFontSize, color: Colors.black87, fontWeight: FontWeight.bold
      ),
      items: lengthOptions.map((length) {
        return DropdownMenuItem<String>(
          value: length,
          child: Text(length),
        );
      }).toList(),
      onChanged: (value) {
        setState(() => selectedStoryLength = value!);
      },
    );
  }

  Widget _buildLabeledCard(String label, Widget content, double baseFontSize) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 500),
        child: Card(
          color: const Color(0xFFE7E6D9),
          elevation: 3,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (ctx, constraints) {
      final screenWidth = constraints.maxWidth;
      final baseFontSize = (screenWidth * 0.03).clamp(14.0, 20.0);
      final dimensionWidgets = _buildGroupedDimensionWidgets(baseFontSize);

      return Scaffold(
        backgroundColor: const Color(0xFFC27b31),
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
                SizedBox(height: baseFontSize),
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
                ...dimensionWidgets,
                SizedBox(height: baseFontSize * 1.2),
                _buildLabeledCard(
                  "Number of Options:",
                  _buildOptionCountDropdown(baseFontSize),
                  baseFontSize,
                ),
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
          onPressed: widget.isGroup ? startGroupStory : startSoloStory,
          label: Text(
            widget.isGroup ? "Proceed to Host Lobby" : "Start Story",
            style: GoogleFonts.atma(
              color: Colors.black87,
              fontSize: baseFontSize,
              fontWeight: FontWeight.bold,
            ),
          ),
          backgroundColor: const Color(0xFFE7E6D9),
        ),
      );
    });
  }
}

