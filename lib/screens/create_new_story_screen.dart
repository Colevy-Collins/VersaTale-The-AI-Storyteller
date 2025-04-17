import 'dart:math';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/dimension_map.dart';          // your groupedDimensionOptions
import '../services/dimension_exclusions.dart';   // NEW
import '../widgets/dimension_dropdown.dart';
import '../services/story_service.dart';
import 'story_screen.dart';
import 'multiplayer_host_lobby_screen.dart';

class CreateNewStoryScreen extends StatefulWidget {
  final bool isGroup;
  final String? sessionId;
  final String? joinCode;
  final Map<String, dynamic>? initialDimensionData;
  final Map<int, Map<String, dynamic>>? initialPlayersMap;

  const CreateNewStoryScreen({
    Key? key,
    required this.isGroup,
    this.sessionId,
    this.joinCode,
    this.initialDimensionData,
    this.initialPlayersMap,
  }) : super(key: key);

  @override
  _CreateNewStoryScreenState createState() => _CreateNewStoryScreenState();
}

class _CreateNewStoryScreenState extends State<CreateNewStoryScreen> {
  final StoryService storyService = StoryService();
  bool isLoading = false;
  int maxLegs = 10;
  int selectedOptionCount = 2;
  String selectedStoryLength = "Short";

  late Map<String, dynamic> dimensionOptions;
  final Map<String, String?> userSelections = {};
  final Map<String, bool> expansionState = {};

  @override
  void initState() {
    super.initState();
    // Always show the full set of dimensions to both hosts & joiners:
    dimensionOptions = groupedDimensionOptions;

    // Initialize all groups as collapsed
    dimensionOptions.forEach((groupName, _) {
      expansionState[groupName] = false;
    });
  }

  List<Widget> _buildGroupedDimensionWidgets(double baseFontSize) {
    final List<Widget> groupWidgets = [];
    dimensionOptions.forEach((groupName, dims) {
      if (excludedDimensions.contains(groupName)) return;
      if (dims is Map<String, dynamic>) {
        final dropdowns = _buildDimensionDropdownsForGroup(dims, baseFontSize);
        if (dropdowns.isEmpty) return;
        groupWidgets.add(
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8.0),
            child: Card(
              color: const Color(0xFFE7E6D9),
              elevation: 3,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              child: ExpansionTile(
                key: PageStorageKey(groupName),
                title: Text(groupName,
                    style: GoogleFonts.atma(
                        fontSize: baseFontSize + 2,
                        fontWeight: FontWeight.bold)),
                initiallyExpanded: expansionState[groupName]!,
                onExpansionChanged: (exp) =>
                    setState(() => expansionState[groupName] = exp),
                children: dropdowns,
              ),
            ),
          ),
        );
      }
    });
    return groupWidgets;
  }

  List<Widget> _buildDimensionDropdownsForGroup(
      Map<String, dynamic> dims, double baseFontSize) {
    final List<Widget> widgets = [];
    dims.forEach((dimKey, dimVal) {
      if (excludedDimensions.contains(dimKey)) return;
      if (dimVal is List) {
        widgets.add(
          Padding(
            padding:
            const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: DimensionDropdown(
              label: dimKey,
              options: List<String>.from(dimVal),
              initialValue: userSelections[dimKey],
              onChanged: (val) =>
                  setState(() => userSelections[dimKey] = val),
            ),
          ),
        );
      }
    });
    return widgets;
  }

  Map<String, dynamic> _buildDimensionSelectionData() {
    final data = <String, dynamic>{};
    groupedDimensionOptions.forEach((_, groupVals) {
      if (groupVals is Map<String, dynamic>) {
        groupVals.forEach((k, v) {
          if (v is List) {
            final choice = userSelections[k];
            final opts = List<String>.from(v);
            data[k] = choice ?? (opts..shuffle()).first;
          }
        });
      }
    });
    data["optionCount"] = selectedOptionCount;
    data["storyLength"] = selectedStoryLength;
    return data;
  }

  Map<String, String> _buildVoteData() {
    final vote = <String, String>{};
    userSelections.forEach((k, v) {
      if (v != null) vote[k] = v;
    });
    return vote;
  }

  Future<void> _startSoloStory() async {
    setState(() => isLoading = true);
    try {
      final dims = _buildDimensionSelectionData();
      final res = await storyService.startStory(
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
            initialLeg: res["storyLeg"],
            options: List<String>.from(res["options"]),
            storyTitle: res["storyTitle"],
          ),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text("$e")));
    } finally {
      setState(() => isLoading = false);
    }
  }

  Future<void> _startGroupStory() async {
    setState(() => isLoading = true);
    try {
      final payload = {
        "decision": "Start Story",
        "dimensions": _buildDimensionSelectionData(),
        "maxLegs": maxLegs,
        "optionCount": selectedOptionCount,
        "storyLength": selectedStoryLength,
        "vote": _buildVoteData(),
      };
      final result = await storyService.startGroupStory(payload);
      final players = Map<String, dynamic>.from(result["players"] ?? {});
      final parsed = players.map<int, Map<String, dynamic>>(
            (k, v) => MapEntry(int.parse(k), Map<String, dynamic>.from(v)),
      );
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => MultiplayerHostLobbyScreen(
            dimensionData: result["storyState"]["dimensions"] ?? {},
            sessionId: result["sessionId"],
            joinCode: result["joinCode"],
            playersMap: parsed,
          ),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text("$e")));
    } finally {
      setState(() => isLoading = false);
    }
  }

  Future<void> _submitGroupVote() async {
    setState(() => isLoading = true);
    try {
      await storyService.submitVote(_buildVoteData());
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => MultiplayerHostLobbyScreen(
            dimensionData: groupedDimensionOptions,
            sessionId: widget.sessionId!,
            joinCode: widget.joinCode!,
            playersMap: widget.initialPlayersMap!,
          ),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text("Vote failed: $e")));
    } finally {
      setState(() => isLoading = false);
    }
  }

  Widget _buildOptionCountDropdown(double fs) {
    return DropdownButton<int>(
      value: selectedOptionCount,
      isExpanded: true,
      style: GoogleFonts.atma(
          fontSize: fs, fontWeight: FontWeight.bold, color: Colors.black87),
      items: [2, 3, 4]
          .map((c) => DropdownMenuItem(value: c, child: Text(c.toString())))
          .toList(),
      onChanged: (v) => setState(() => selectedOptionCount = v!),
    );
  }

  Widget _buildStoryLengthDropdown(double fs) {
    return DropdownButton<String>(
      value: selectedStoryLength,
      isExpanded: true,
      style: GoogleFonts.atma(
          fontSize: fs, fontWeight: FontWeight.bold, color: Colors.black87),
      items: ["Short", "Medium", "Long"]
          .map((s) => DropdownMenuItem(value: s, child: Text(s)))
          .toList(),
      onChanged: (v) => setState(() => selectedStoryLength = v!),
    );
  }

  Widget _buildLabeledCard(String label, Widget content, double fs) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 500),
        child: Card(
          color: const Color(0xFFE7E6D9),
          elevation: 3,
          shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: GoogleFonts.atma(
                        fontSize: fs,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87)),
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
    final isJoiner = widget.isGroup && widget.sessionId != null;
    return LayoutBuilder(builder: (ctx, cons) {
      final w = cons.maxWidth;
      final baseFS = (w * 0.03).clamp(14.0, 20.0);
      final dims = _buildGroupedDimensionWidgets(baseFS);

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
                SizedBox(height: baseFS),
                Text(
                  widget.isGroup
                      ? (isJoiner
                      ? "Vote on Story Settings"
                      : "Configure Group Story")
                      : "Create Your New Adventure",
                  textAlign: TextAlign.center,
                  style: GoogleFonts.atma(
                    fontSize: baseFS + 8,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                SizedBox(height: baseFS),
                ...dims,
                if (!isJoiner) ...[
                  _buildLabeledCard(
                      "Number of Options:", _buildOptionCountDropdown(baseFS), baseFS),
                  _buildLabeledCard("Story Length:", _buildStoryLengthDropdown(baseFS), baseFS),
                  SizedBox(height: baseFS * 2),
                ],
              ],
            ),
          ),
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: isJoiner ? _submitGroupVote : (widget.isGroup ? _startGroupStory : _startSoloStory),
          label: Text(
            widget.isGroup
                ? (isJoiner ? "Submit Votes" : "Proceed to Lobby")
                : "Start Story",
            style: GoogleFonts.atma(fontSize: baseFS, fontWeight: FontWeight.bold),
          ),
          backgroundColor: const Color(0xFFE7E6D9),
        ),
      );
    });
  }
}
