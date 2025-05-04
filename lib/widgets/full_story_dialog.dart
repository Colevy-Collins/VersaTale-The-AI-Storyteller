// lib/widgets/full_story_dialog.dart
// -----------------------------------------------------------------------------
// Shows the full story so far and lets the player choose the next action.
// Dialog scales gracefully from wear‑OS‑size screens (≈ 240 × 340 px)
// up to desktop (560 × 600 px).
// -----------------------------------------------------------------------------

import 'package:flutter/material.dart';
import 'action_button.dart';

class FullStoryDialog extends StatefulWidget {
  /// Complete story text shown inside the dialog.
  final String storyText;

  /// List of choices the player can select next.
  final List<String> choiceOptions;

  /// Callback when the user taps a specific choice.
  final ValueChanged<String> onChoiceSelected;

  /// Opens a bottom‑sheet / dialog that lists [choiceOptions] to choose from.
  final VoidCallback onShowChoices;

  /// If `false`, the “Choose Next Action” button is disabled.
  final bool isChoiceSelectable;

  const FullStoryDialog({
    super.key,
    required this.storyText,
    required this.choiceOptions,
    required this.onChoiceSelected,
    required this.onShowChoices,
    required this.isChoiceSelectable,
  });

  @override
  State<FullStoryDialog> createState() => _FullStoryDialogState();
}

class _FullStoryDialogState extends State<FullStoryDialog> {
  final ScrollController _contentScrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    // Auto‑scroll to the bottom once the frame is rendered.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _contentScrollController.jumpTo(
        _contentScrollController.position.maxScrollExtent,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme colorScheme = Theme.of(context).colorScheme;
    final TextTheme   textTheme   = Theme.of(context).textTheme;

    /*──────────────────── responsive bounds ────────────────────*/
    final Size   screen          = MediaQuery.of(context).size;
    const double kMaxWidth       = 560;
    const double kMaxHeight      = 600;
    final double dialogWidth     = screen.width  < kMaxWidth
        ? screen.width  * 0.95
        : kMaxWidth;
    final double dialogHeight    = screen.height < kMaxHeight
        ? screen.height * 0.85
        : kMaxHeight;

    return Dialog(
      insetPadding: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      backgroundColor: colorScheme.surface,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth : dialogWidth,
          maxHeight: dialogHeight,
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),        // slightly slimmer padding
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch, // << NEW
            children: [
              Center(
                child: Text(
                  'Current Story',
                  style: textTheme.titleLarge
                      ?.copyWith(fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(height: 12),

              /*────────────── scrollable story text ───────────────*/
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    border: Border.all(color: colorScheme.outline),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Scrollbar(
                    controller: _contentScrollController,
                    child: SingleChildScrollView(
                      controller: _contentScrollController,
                      padding: const EdgeInsets.all(8),
                      child: ConstrainedBox(               // << NEW
                        constraints:
                        const BoxConstraints(minWidth: double.infinity),
                        child: Text(widget.storyText,
                            style: textTheme.bodyLarge),
                      ),
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 16),

              /*──────────── choose‑next‑action button ─────────────*/
              if (widget.choiceOptions.isNotEmpty)
                ActionButton(
                  label: 'Choose Next Action',
                  onPressed: widget.isChoiceSelectable
                      ? widget.onShowChoices
                      : null,
                ),

              const SizedBox(height: 8),

              /*──────────────────── close ────────────────────*/
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(
                  'Close',
                  style: textTheme.labelLarge
                      ?.copyWith(fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

}
