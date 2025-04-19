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
        minimumSize: const Size.fromHeight(48),
      ),
      child: busy
          ? const CircularProgressIndicator()
          : Text(label, style: GoogleFonts.atma(fontWeight: FontWeight.bold)),
    );
  }
}
