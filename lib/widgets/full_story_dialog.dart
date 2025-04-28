import 'package:flutter/material.dart';
import 'action_button.dart';

class FullStoryDialog extends StatefulWidget {
  final String fullStory;
  final List<String> dialogOptions;
  final ValueChanged<String> onOptionSelected;
  final VoidCallback onShowOptions;
  final bool canPick;

  const FullStoryDialog({
    super.key,
    required this.fullStory,
    required this.dialogOptions,
    required this.onOptionSelected,
    required this.onShowOptions,
    required this.canPick,
  });

  @override
  State<FullStoryDialog> createState() => _FullStoryDialogState();
}

class _FullStoryDialogState extends State<FullStoryDialog> {
  final _scroll = ScrollController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback(
          (_) => _scroll.jumpTo(_scroll.position.maxScrollExtent),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      backgroundColor: cs.surface,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Current Story',
                style: tt.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            Container(
              height: 300,
              decoration: BoxDecoration(
                border: Border.all(color: cs.outline),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Scrollbar(
                controller: _scroll,
                child: SingleChildScrollView(
                  controller: _scroll,
                  padding: const EdgeInsets.all(8),
                  child: Text(widget.fullStory, style: tt.bodyLarge),
                ),
              ),
            ),
            const SizedBox(height: 16),
            if (widget.dialogOptions.isNotEmpty)
              ActionButton(
                label: 'Choose Next Action',
                onPressed: widget.canPick ? widget.onShowOptions : null,
              ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Close',
                  style:
                  tt.labelLarge?.copyWith(fontWeight: FontWeight.w600)),
            ),
          ],
        ),
      ),
    );
  }
}
