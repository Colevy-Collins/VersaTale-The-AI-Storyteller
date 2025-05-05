import 'package:flutter/material.dart';

/// Large rounded button used across host / join screens.
class PrimaryActionButton extends StatelessWidget {
  const PrimaryActionButton({
    super.key,
    required this.label,
    required this.onPressed,
    required this.maxWidth,
  });

  final String label;
  final VoidCallback onPressed;
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: cs.primary,
            foregroundColor: cs.onPrimary,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          onPressed: onPressed,
          child: FittedBox(
            fit : BoxFit.scaleDown,
            child: Text(label, style: tt.labelLarge?.copyWith(fontWeight: FontWeight.bold)),
          ),
        ),
      ),
    );
  }
}
