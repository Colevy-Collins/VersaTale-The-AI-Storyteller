// lib/widgets/next_action_sheet.dart
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'action_button.dart';

class NextActionSheet extends StatelessWidget {
  final List<String> options;
  final bool busy;
  final VoidCallback onPrevious;
  final ValueChanged<String> onSelect;

  const NextActionSheet({
    Key? key,
    required this.options,
    required this.busy,
    required this.onPrevious,
    required this.onSelect,
  }) : super(key: key);

  @override
  Widget build(BuildContext ctx) {
    return Container(
      height: 300,
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      child: ListView(
        children: [
          ActionButton(
            label: 'Previous Leg',
            busy: busy,
            onPressed: () {
              Navigator.pop(ctx);
              onPrevious();
            },
          ),
          const SizedBox(height: 8),
          ...options.map((choice) {
            final isFinal = choice == 'The story ends';
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: ActionButton(
                label: isFinal ? 'The story ends' : choice,
                busy: busy || isFinal,
                onPressed: () {
                  Navigator.pop(ctx);
                  onSelect(choice);
                },
              ),
            );
          }).toList(),
        ],
      ),
    );
  }
}
