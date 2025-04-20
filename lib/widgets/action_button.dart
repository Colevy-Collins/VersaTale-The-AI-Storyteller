// lib/widgets/action_button.dart
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class ActionButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final bool busy;

  const ActionButton({
    Key? key,
    required this.label,
    required this.onPressed,
    this.busy = false,
  }) : super(key: key);

  @override
  Widget build(BuildContext ctx) {
    return ElevatedButton(
      onPressed: busy ? null : onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color(0xFF7FBFC5).withOpacity(0.8),
        foregroundColor: const Color(0xFF212121),
        minimumSize: const Size.fromHeight(48),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: Colors.brown.shade500, width: 1.5),
        ),
        textStyle: GoogleFonts.kottaOne(
          fontWeight: FontWeight.w800,
          fontSize: 16,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 20),
        child: busy
            ? const SizedBox(
          width: 24,
          height: 24,
          child: CircularProgressIndicator(strokeWidth: 2),
        )
            : Text(label),
      ),
    );
  }
}

// Note: Add a placeholder image at assets/parchment.png and register it in pubspec.yaml:
//   assets:
//     - assets/parchment.png
