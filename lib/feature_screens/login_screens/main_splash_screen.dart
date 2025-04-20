import 'dart:math';
import 'package:flutter/material.dart';
import 'login_page.dart';
import 'register_screen.dart';

class MainSplashScreen extends StatelessWidget {
  const MainSplashScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Stack(
          children: [
            // 1) Full-screen background image
            Positioned.fill(
              child: Image.asset(
                "assets/versatale_home_image.png",
                fit: BoxFit.cover,
              ),
            ),

            // 2) Bottom-aligned buttons
            LayoutBuilder(
              builder: (context, constraints) {
                final double buttonWidth = constraints.maxWidth * 0.6;
                final double buttonFontSize = min(constraints.maxWidth * 0.05, 28.0);

                return Align(
                  alignment: Alignment.bottomCenter,
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 40.0),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Login button
                        SizedBox(
                          width: buttonWidth,
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.black.withOpacity(0.2),
                              shadowColor: Colors.black,
                              elevation: 8.0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(builder: (_) => const LoginPage()),
                              );
                            },
                            child: Text(
                              'Login',
                              style: TextStyle(
                                fontSize: buttonFontSize,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),

                        // Sign Up button
                        SizedBox(
                          width: buttonWidth,
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.black.withOpacity(0.2),
                              shadowColor: Colors.black,
                              elevation: 8.0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(builder: (_) => const RegisterScreen()),
                              );
                            },
                            child: Text(
                              "Don't have an account? Sign Up",
                              style: TextStyle(
                                fontSize: buttonFontSize,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
