import 'package:flutter/material.dart';

class ActionButton extends StatelessWidget {
  const ActionButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.busy = false,
  });

  final String       label;
  final VoidCallback? onPressed;
  final bool         busy;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return ElevatedButton(
      onPressed: busy ? null : onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: cs.primary,
        foregroundColor: cs.onPrimary,
        minimumSize     : const Size.fromHeight(48),
        shape           : RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side        : BorderSide(color: cs.secondary, width: 1.5),
        ),
        textStyle: tt.labelLarge?.copyWith(fontWeight: FontWeight.w700),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 20),
        child: busy
            ? const SizedBox(
            width: 24, height: 24,
            child: CircularProgressIndicator(strokeWidth: 2))
            : Text(label),
      ),
    );
  }
}
