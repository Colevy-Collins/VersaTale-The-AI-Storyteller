import 'package:flutter/material.dart';
import 'action_button.dart';

class NextActionSheet extends StatelessWidget {
  const NextActionSheet({
    super.key,
    required this.options,
    required this.busy,
    required this.onPrevious,
    required this.onSelect,
  });

  final List<String>         options;
  final bool                 busy;
  final VoidCallback         onPrevious;
  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context) {
    return Container(
      height : 300,
      padding: const EdgeInsets.all(16),
      child  : ListView(
        children: [
          /// “Previous leg”
          ActionButton(
            label   : 'Previous Leg',
            busy    : busy,
            onPressed: busy
                ? null
                : () {
              Navigator.pop(context);
              onPrevious();
            },
          ),
          const SizedBox(height: 8),

          /// Player choices
          ...options.map(
                (choice) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: ActionButton(
                label   : choice,
                busy    : busy,
                onPressed: (busy || choice == '1. The story ends')
                    ? null
                    : () {
                  Navigator.pop(context);
                  onSelect(choice);
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}
