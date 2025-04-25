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
          // “Previous Leg” button stays enabled when not busy
          ActionButton(
            label: 'Previous Leg',
            busy: busy,
            onPressed: busy
                ? null
                : () {
              Navigator.pop(ctx);
              onPrevious();
            },
          ),
          const SizedBox(height: 8),

          // Render each choice, disabling the “The story ends!” option
          ...options.map((choice) {
            final isFinal = choice == '1. The story ends';

            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: ActionButton(
                label: choice,
                busy: busy,
                // Disable if busy or if it's the final sentinel
                onPressed: (busy || isFinal)
                    ? null
                    : () {
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
