// lib/widgets/parchment_background.dart
//
// Scroll‑friendly parchment backdrop
// ──────────────────────────────────
// • WIDTH tracks [contentWidth]  →  fields look glued to the scroll.
// • HEIGHT tiles the bitmap vertically (repeatY) so it grows with the page.
// • bottomBleed adds a little extra parchment *below* your content so the
//   final button never “falls off” the scroll.
//
//   ParchmentBackground(
//     contentWidth : cardMaxW,
//     child        : <your column>,
//     // bottomBleed: 140,          // optional override
//   )

import 'package:flutter/material.dart';

class ParchmentBackground extends StatelessWidget {
  const ParchmentBackground({
    super.key,
    required this.child,
    required this.contentWidth,
    this.bottomBleed = 120,         // px of parchment below the last widget
  });

  final Widget child;
  final double contentWidth;
  final double bottomBleed;

  @override
  Widget build(BuildContext context) {
    // Width = form + 60‑px curls on both sides.
    final double imgWidth = contentWidth + 120;

    return Stack(
      clipBehavior: Clip.none,
      children: [
        /* ── parchment texture ─────────────────────────────── */
        Positioned.fill(
          child: Align(
            alignment: Alignment.topCenter,
            child: IgnorePointer(
              child: Opacity(
                opacity: 0.6,
                child: Container(
                  width: imgWidth,
                  decoration: const BoxDecoration(
                    image: DecorationImage(
                      image : AssetImage('assets/best_scroll.jpg'),
                      fit   : BoxFit.cover,
                      repeat: ImageRepeat.repeatY, // tile downwards
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),

        /* ── foreground content + extra bottom space ───────── */
        Align(
          alignment: Alignment.topCenter,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              child,
              SizedBox(height: bottomBleed), // keeps button on the scroll
            ],
          ),
        ),
      ],
    );
  }
}
