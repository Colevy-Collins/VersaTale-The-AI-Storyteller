import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Blue (info) snackbar
void showSnack(BuildContext ctx, String msg) =>
    ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content: Text(msg)));

/// Red (error) snackbar
void showError(BuildContext ctx, String msg) =>
    ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(
      backgroundColor: Colors.red.shade400,
      content: Text(msg),
    ));

/// Generic YES/NO dialog that returns `true` when the user confirms.
Future<bool> confirmDialog({
  required BuildContext ctx,
  required String title,
  required String message,
}) async =>
    (await showDialog<bool>(
      context: ctx,
      builder: (_) => AlertDialog(
        title: Text(title, style: GoogleFonts.atma()),
        content: Text(message, style: GoogleFonts.atma()),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancel', style: GoogleFonts.atma()),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('Continue', style: GoogleFonts.atma()),
          ),
        ],
      ),
    )) ??
        false;
