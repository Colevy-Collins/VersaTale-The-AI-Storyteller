// lib/widgets/action_button.dart
// -----------------------------------------------------------------------------
// One‑tap button used throughout the app.
// • Shows a spinner when [busy] == true.
// • Automatically disables when [onPressed] == null.
// • NEW: The label Text now wraps (softWrap: true) so long lines stay readable.
// -----------------------------------------------------------------------------

import 'package:flutter/material.dart';

class ActionButton extends StatelessWidget {
  const ActionButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.busy = false,
  });

  /// Button label (can be multi‑line; will wrap automatically).
  final String       label;

  /// Whether to show a CircularProgressIndicator.
  final bool         busy;

  /// Callback (null → disabled).
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final disabled = onPressed == null;

    return ElevatedButton(
      style: ElevatedButton.styleFrom(
        minimumSize   : const Size.fromHeight(48),
        padding       : const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        backgroundColor: disabled
            ? cs.primary.withOpacity(.3)
            : cs.primary,
        foregroundColor: cs.onPrimary,
        textStyle     : Theme.of(context).textTheme.titleMedium,
        shape         : RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
      onPressed: disabled ? null : onPressed,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize     : MainAxisSize.min,
        children: [
          // Expanded lets the label wrap instead of being forced into one line.
          Flexible(
            child: Text(
              label,
              textAlign: TextAlign.center,
              softWrap : true,           // ← NEW: allow wrapping
              overflow : TextOverflow.visible,
            ),
          ),
          if (busy) ...[
            const SizedBox(width: 12),
            SizedBox(
              height: 18,
              width : 18,
              child : CircularProgressIndicator(
                strokeWidth: 2,
                valueColor : AlwaysStoppedAnimation<Color>(cs.onPrimary),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
