import 'package:flutter/material.dart';
import '../utils/ui_utils.dart';

class AdaptiveConfirmDialog extends StatelessWidget {
  const AdaptiveConfirmDialog({
    super.key,
    required this.title,
    required this.message,
    this.confirmLabel = 'OK',
  });

  final String title;
  final String message;
  final String confirmLabel;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Dialog(
      insetPadding : EdgeInsets.zero,
      shape        : RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      backgroundColor: cs.surface,
      child: ConstrainedBox(
        constraints: dialogConstraints(context),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize : MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(child: Text(title, style: tt.titleLarge?.copyWith(fontWeight: FontWeight.bold))),
              const SizedBox(height: 12),
              Text(message, style: tt.bodyLarge),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(onPressed: Navigator.of(context).pop, child: const Text('Cancel')),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: () => Navigator.pop(context, true),
                    child   : Text(confirmLabel),
                  ),
                ],
              )
            ],
          ),
        ),
      ),
    );
  }
}

class AdaptiveInputDialog extends StatefulWidget {
  const AdaptiveInputDialog({
    super.key,
    required this.title,
    this.hintText,
  });

  final String title;
  final String? hintText;

  @override
  State<AdaptiveInputDialog> createState() => _AdaptiveInputDialogState();
}

class _AdaptiveInputDialogState extends State<AdaptiveInputDialog> {
  final _ctrl = TextEditingController();

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Dialog(
      insetPadding : EdgeInsets.zero,
      shape        : RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      backgroundColor: cs.surface,
      child: ConstrainedBox(
        constraints: dialogConstraints(context),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize : MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(child: Text(widget.title, style: tt.titleLarge?.copyWith(fontWeight: FontWeight.bold))),
              const SizedBox(height: 12),
              TextField(
                controller : _ctrl,
                autofocus  : true,
                decoration : InputDecoration(
                    hintText: widget.hintText ?? '',
                    border  : const OutlineInputBorder()),
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(onPressed: Navigator.of(context).pop, child: const Text('Cancel')),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: () => Navigator.pop(context, _ctrl.text.trim()),
                    child   : const Text('OK'),
                  ),
                ],
              )
            ],
          ),
        ),
      ),
    );
  }
}
