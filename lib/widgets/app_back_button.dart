import 'package:flutter/material.dart';

/// Tiny, ink‑splash‑free back arrow that matches every screen.
class AppBackButton extends StatelessWidget {
  const AppBackButton({super.key});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        color: cs.surfaceVariant.withOpacity(.6),
        borderRadius: BorderRadius.circular(4),
      ),
      child: IconButton(
        iconSize: 20,
        padding : EdgeInsets.zero,
        icon    : Icon(Icons.arrow_back, color: cs.onSurface),
        onPressed: () => Navigator.of(context).maybePop(),
      ),
    );
  }
}
