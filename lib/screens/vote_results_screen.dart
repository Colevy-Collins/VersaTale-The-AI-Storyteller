// lib/screens/vote_results_screen.dart

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/dimension_exclusions.dart';
import 'story_screen.dart';

class VoteResultsScreen extends StatelessWidget {
  /// Each dimension key mapped to its final chosen value.
  final Map<String, String> resolvedResults;

  const VoteResultsScreen({
    Key? key,
    required this.resolvedResults,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // 1) Filter out excluded dimensions
    final dims = resolvedResults.keys
        .where((k) => !excludedDimensions.contains(k))
        .toList()
      ..sort();

    return Scaffold(
      appBar: AppBar(
        title: Text("Vote Results", style: GoogleFonts.atma()),
        automaticallyImplyLeading: false,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: ListView.builder(
          itemCount: dims.length,
          itemBuilder: (context, idx) {
            final dimKey = dims[idx];
            final value = resolvedResults[dimKey]!;

            return Card(
              margin: const EdgeInsets.symmetric(vertical: 6),
              child: ListTile(
                title: Text(dimKey, style: GoogleFonts.atma(fontWeight: FontWeight.bold)),
                subtitle: Text(value, style: GoogleFonts.atma()),
              ),
            );
          },
        ),
      ),
      bottomNavigationBar: Padding(
        padding: const EdgeInsets.all(16),
        child: ElevatedButton(
          onPressed: () {
            // TODO: Initialize and navigate to your StoryScreen
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (_) => StoryScreen(
                  initialLeg: "",
                  options: const [],
                  storyTitle: "",
                ),
              ),
            );
          },
          child: Text("Continue to Story", style: GoogleFonts.atma()),
        ),
      ),
    );
  }
}
