import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';

/// ────────────────────────────────────────────────────────────
/// Global helpers – snack bars, errors, external links, sizing
/// ────────────────────────────────────────────────────────────
bool isTinyLandscape(BuildContext ctx, {double threshold = 320}) {
  final size = MediaQuery.of(ctx).size;
  return size.height < threshold && size.width > size.height;
}

// ––– General toasts –––
void showSnack(BuildContext ctx, String msg) {
  ScaffoldMessenger.of(ctx).showSnackBar(
    SnackBar(content: Text(msg, style: GoogleFonts.atma())),
  );
}

void showError(BuildContext ctx, String msg) {
  ScaffoldMessenger.of(ctx).showSnackBar(
    SnackBar(
      backgroundColor: Colors.red,
      content: Text(msg, style: GoogleFonts.atma()),
    ),
  );
}

// ––– External links –––
Future<void> openTutorialPdf(BuildContext ctx) async {
  const url = 'https://drive.google.com/file/d/1uuDpQgOMNE-SEmvWfmKA36rhoLYsXcSW/preview';
  showSnack(ctx, 'Opening tutorial…');
  final uri = Uri.parse(url);

  if (await canLaunchUrl(uri)) {
    await launchUrl(uri, webOnlyWindowName: '_blank');
  } else {
    showError(ctx, 'Could not open tutorial PDF.');
  }
}

/// Returns tight dialog constraints that mimic the FullStoryDialog look.
///
/// Keeps dialogs comfortably readable on phone‑sized displays.
BoxConstraints dialogConstraints(BuildContext context) {
  const double kMaxW = 560, kMaxH = 600;
  final size = MediaQuery.of(context).size;
  final maxW = size.width  < kMaxW ? size.width  * .95 : kMaxW;
  final maxH = size.height < kMaxH ? size.height * .85 : kMaxH;
  return BoxConstraints(maxWidth: maxW, maxHeight: maxH);
}

/// Returns `true` on “tiny” screens (either width *or* height below [threshold]).
///
/// Default threshold = 320 px, so 240 × 340 and 340 × 240 are both tiny.
bool isTinyScreen(BuildContext ctx, {double threshold = 320}) {
  final size = MediaQuery.of(ctx).size;
  return size.width < threshold || size.height < threshold;
}

/// Simple YES / NO confirm dialog that resolves to `true` on confirm.
Future<bool> confirmDialog({
  required BuildContext ctx,
  required String title,
  required String message,
  String confirmLabel = 'Continue',
}) async {
  return (await showDialog<bool>(
    context: ctx,
    builder: (_) => Dialog(
      insetPadding: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: dialogConstraints(_),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(title,
                  style: GoogleFonts.atma(fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              Text(message, style: GoogleFonts.atma()),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(_, false),
                    child: Text('Cancel', style: GoogleFonts.atma(fontSize: 16)),
                  ),
                  const SizedBox(width: 8),
                  TextButton(
                    onPressed: () => Navigator.pop(_, true),
                    child: Text(confirmLabel, style: GoogleFonts.atma(fontSize: 16)),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    ),
  )) ??
      false;
}
