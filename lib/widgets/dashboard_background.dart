import 'package:flutter/material.dart';

/// Parchment‑style background used on the home dashboard.
class DashboardBackground extends StatelessWidget {
  const DashboardBackground({super.key});

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: const DecoratedBox(
        decoration: BoxDecoration(
          image: DecorationImage(
            image: AssetImage('assets/versatale_dashboard2_image.png'),
            fit: BoxFit.cover,
          ),
        ),
      ),
    );
  }
}
