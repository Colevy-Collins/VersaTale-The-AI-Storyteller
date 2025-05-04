// lib/feature_screens/login_screens/main_splash_screen.dart
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../utils/force_update_web.dart';   // ← new (lives in lib/utils)
import 'login_page.dart';
import 'register_screen.dart';
import '../../utils/ui_utils.dart';          // openTutorialPdf()

class MainSplashScreen extends StatefulWidget {
  const MainSplashScreen({Key? key}) : super(key: key);

  @override
  State<MainSplashScreen> createState() => _MainSplashScreenState();
}

class _MainSplashScreenState extends State<MainSplashScreen> {
  @override
  void initState() {
    super.initState();
    // Forces a single hard‑refresh if a newer build is available (web only).
    ForceUpdateWeb.runOnce();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, c) {
            final w         = c.maxWidth;
            final h         = c.maxHeight;
            final btnWidth  = w * 0.7;                 // responsive button size
            final fontLarge = min(w * 0.06, 28.0);
            final fontSmall = fontLarge * 0.85;

            return Stack(
              children: [
                // Background image
                Positioned.fill(
                  child: Image.asset(
                    'assets/versatale_home_image.png',
                    fit: BoxFit.cover,
                  ),
                ),

                // Buttons – kept at the bottom and centered
                Align(
                  alignment: Alignment.bottomCenter,
                  child: Padding(
                    padding: EdgeInsets.only(
                        bottom: h < 400 ? 16 : 40, left: 12, right: 12),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _primaryButton(
                          label: 'Log In',
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (_) => const LoginPage()),
                          ),
                          width: btnWidth,
                          fontSize: fontLarge,
                        ),
                        const SizedBox(height: 18),
                        _primaryButton(
                          label: 'Don\'t have an account? Sign Up',
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (_) => const RegisterScreen()),
                          ),
                          width: btnWidth,
                          fontSize: fontSmall,
                        ),
                        const SizedBox(height: 20),
                        Container(
                          height: 1,
                          width: btnWidth * 0.8,
                          color: Colors.white.withOpacity(0.35),
                        ),
                        const SizedBox(height: 12),
                        _secondaryButton(
                          label: 'Tutorial',
                          icon: Icons.menu_book,
                          onTap: () => openTutorialPdf(context),
                          width: btnWidth * 0.8,
                          fontSize: fontSmall,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // UI helpers
  // ---------------------------------------------------------------------------

  Widget _primaryButton({
    required String label,
    required VoidCallback onTap,
    required double width,
    required double fontSize,
  }) {
    return SizedBox(
      width: width,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.black.withOpacity(0.25),
          foregroundColor: Colors.white,
          shadowColor: Colors.black54,
          elevation: 6,
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
        onPressed: onTap,
        child: Text(label,
            style: TextStyle(fontSize: fontSize, fontWeight: FontWeight.bold)),
      ),
    );
  }

  Widget _secondaryButton({
    required String label,
    required IconData icon,
    required VoidCallback onTap,
    required double width,
    required double fontSize,
  }) {
    return SizedBox(
      width: width,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.white.withOpacity(0.15),
          foregroundColor: Colors.white,
          elevation: 4,
          padding: const EdgeInsets.symmetric(vertical: 10),
          shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
        onPressed: onTap,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: fontSize * 0.9),
            const SizedBox(width: 6),
            Text(label,
                style:
                TextStyle(fontSize: fontSize, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }
}
