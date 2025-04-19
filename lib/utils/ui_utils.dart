// lib/utils/ui_utils.dart
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

extension SnackBarExtension on BuildContext {
  /// Shows a SnackBar with [msg].  Red if [isError]==true.
  void showMessage(String msg, {bool isError = false}) {
    ScaffoldMessenger.of(this).showSnackBar(
      SnackBar(
        content: Text(msg, style: GoogleFonts.atma()),
        backgroundColor: isError ? Colors.red : null,
      ),
    );
  }
}
