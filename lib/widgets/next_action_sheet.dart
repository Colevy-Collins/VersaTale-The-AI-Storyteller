import 'package:flutter/material.dart';
import 'action_button.dart';

/// Bottom sheet that shows the “Previous Leg” control plus all choice options.
///
/// • If *any* option contains the exact phrase **"The story ends"**, all choice
///   buttons become disabled (but “Previous Leg” stays enabled).
/// • Disabled buttons fade to 40 % opacity for visual feedback.
class NextActionSheet extends StatelessWidget {
  const NextActionSheet({
    super.key,
    required this.options,
    required this.busy,
    required this.onPrevious,
    required this.onSelect,
  });

  /// List of option strings coming from the backend.
  final List<String>         options;

  /// True while we’re waiting for a backend response (individual buttons also
  /// pass `busy` to their own spinners).
  final bool                 busy;

  /// Callback for the “Previous Leg” control.
  final VoidCallback         onPrevious;

  /// Callback when the user selects an option.
  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context) {
    // Block further progression if *any* option signals that the story ended.
    final bool storyEnded =
    options.any((o) => o.contains('The story ends'));

    return Container(
      height : 300,
      padding: const EdgeInsets.all(16),
      child  : ListView(
        children: [
          /* ─────────────── “Previous Leg” ─────────────── */
          _fadeWrapper(
            disabled: busy,           // only disabled while a network call runs
            child: ActionButton(
              label   : 'Previous Leg',
              busy    : busy,
              onPressed: busy
                  ? null
                  : () {
                Navigator.pop(context);
                onPrevious();
              },
            ),
          ),
          const SizedBox(height: 8),

          /* ─────────────── Player choices ─────────────── */
          ...options.map((choice) {
            final bool disabled = busy || storyEnded;
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: _fadeWrapper(
                disabled: disabled,
                child: ActionButton(
                  label   : choice,
                  busy    : busy,
                  onPressed: disabled
                      ? null
                      : () {
                    Navigator.pop(context);
                    onSelect(choice);
                  },
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  /// Wraps a widget in an AnimatedOpacity that drops to 0.4 when [disabled].
  Widget _fadeWrapper({required bool disabled, required Widget child}) {
    return AnimatedOpacity(
      opacity : disabled ? 0.4 : 1.0,
      duration: const Duration(milliseconds: 300),
      child   : child,
    );
  }
}
