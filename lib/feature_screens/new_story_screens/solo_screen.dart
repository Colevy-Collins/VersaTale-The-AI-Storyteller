// lib/screens/solo_story_config.dart
// -----------------------------------------------------------------------------
// Solo Story: pick dimensions then start a solo adventure
// -----------------------------------------------------------------------------
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../services/dimension_map.dart';        // groupedDimensionOptions
import '../../services/dimension_exclusions.dart'; // excludedDimensions list
import '../../widgets/dimension_picker.dart';      // shared dimension UI
import '../../services/story_service.dart';        // backend story start
import '../story_screen.dart';                     // navigation target

class SoloStoryConfig extends StatefulWidget {
  const SoloStoryConfig({Key? key}) : super(key: key);

  @override
  _SoloStoryConfigState createState() => _SoloStoryConfigState();
}

class _SoloStoryConfigState extends State<SoloStoryConfig> {
  final _storySvc = StoryService();

  bool _loading = false;
  int _optionCount = 2;
  String _storyLength = 'Short';

  late final Map<String, dynamic> _dimensionGroups;
  final Map<String, String?> _userChoices = {};  // null = random
  final Map<String, bool> _groupExpanded = {};

  @override
  void initState() {
    super.initState();
    _dimensionGroups = groupedDimensionOptions;
    for (var key in _dimensionGroups.keys) {
      _groupExpanded[key] = false;
    }
  }

  /// Supply random defaults for any unpicked dimension
  Map<String, String> _randomDefaults() {
    final defs = <String, String>{};
    _dimensionGroups.forEach((dim, group) {
      if (group is Map<String, dynamic>) {
        group.forEach((key, values) {
          if (values is List && !excludedDimensions.contains(key)) {
            defs[key] = _userChoices[key]
                ?? (List<String>.from(values)..shuffle()).first;
          }
        });
      }
    });
    return defs;
  }

  Future<void> _startSoloStory() async {
    setState(() => _loading = true);
    try {
      final res = await _storySvc.startStory(
        decision:      'Start Story',
        dimensionData: _randomDefaults(),
        maxLegs:       10,
        optionCount:   _optionCount,
        storyLength:   _storyLength,
      );
      if (!mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => StoryScreen(
            initialLeg: res['storyLeg'],
            options:    List<String>.from(res['options'] ?? []),
            storyTitle: res['storyTitle'],
          ),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFC27B31),
      body: SafeArea(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : LayoutBuilder(
          builder: (ctx, cons) {
            final fs = (cons.maxWidth * 0.03).clamp(14.0, 20.0);
            return SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.arrow_back, color: Colors.white),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                  SizedBox(height: fs),
                  Text(
                    'Create Your New Adventure',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.kottaOne(
                      fontSize: fs + 8,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: fs * 1.5),

                  // dimension picking UI
                  DimensionPicker(
                    groups: _dimensionGroups,
                    choices: _userChoices,
                    expanded: _groupExpanded,
                    onExpand: (key, open) => setState(() => _groupExpanded[key] = open),
                    onChanged: (dim, val) => setState(() => _userChoices[dim] = val),
                  ),

                  SizedBox(height: fs * 2),
                  // option count selector
                  DropdownButton<int>(
                    value: _optionCount,
                    isExpanded: true,
                    style: GoogleFonts.atma(fontSize: fs, fontWeight: FontWeight.bold, color: Colors.black87),
                    items: [2, 3, 4].map((c) => DropdownMenuItem(value: c, child: Text('$c'))).toList(),
                    onChanged: (v) => setState(() => _optionCount = v!),
                  ),

                  SizedBox(height: fs),
                  // story length selector
                  DropdownButton<String>(
                    value: _storyLength,
                    isExpanded: true,
                    style: GoogleFonts.atma(fontSize: fs, fontWeight: FontWeight.bold, color: Colors.black87),
                    items: ['Short', 'Medium', 'Long']
                        .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                        .toList(),
                    onChanged: (v) => setState(() => _storyLength = v!),
                  ),
                  SizedBox(height: fs * 2),
                ],
              ),
            );
          },
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _startSoloStory,
        label: Text(
          'Start Story',
          style: GoogleFonts.kottaOne(fontWeight: FontWeight.bold),
        ),
        backgroundColor: const Color(0xFFE7E6D9),
      ),
    );
  }
}
