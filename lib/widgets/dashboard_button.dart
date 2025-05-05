import 'package:flutter/material.dart';

/// A lightly‑styled button used on the home dashboard.
class DashboardButton extends StatelessWidget {
  const DashboardButton({
    super.key,
    required this.label,
    required this.onPressed,
    required this.fontSize,
  });

  final String label;
  final VoidCallback onPressed;
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return ElevatedButton(
      style: ElevatedButton.styleFrom(
        backgroundColor: cs.surface.withOpacity(.7),
        foregroundColor: cs.onSurface,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      onPressed: onPressed,
      child: Text(
        label,
        textAlign: TextAlign.center,
        style: tt.labelLarge?.copyWith(fontSize: fontSize, fontWeight: FontWeight.bold),
      ),
    );
  }
}
