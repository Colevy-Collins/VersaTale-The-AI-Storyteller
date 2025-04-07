import 'dart:math';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import "../services/story_service.dart";
// Adjust these imports for your project.
import '../services/auth_service.dart';
import 'dashboard_screen.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({Key? key}) : super(key: key);

  @override
  _RegisterScreenState createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  final AuthService authService = AuthService();
  final StoryService storyService = StoryService();

  /// Helper to show color-coded SnackBars:
  ///  - [isError] => red background
  ///  - [isSuccess] => green background
  ///  - otherwise => blue background (info)
  void _showMessage(String message, {bool isError = false, bool isSuccess = false}) {
    Color bgColor;
    if (isError) {
      bgColor = Colors.red;
    } else if (isSuccess) {
      bgColor = Colors.green;
    } else {
      bgColor = Colors.blue;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: bgColor,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> register() async {
    final email = emailController.text.trim();
    final password = passwordController.text.trim();

    // Basic validation
    if (email.isEmpty || password.isEmpty) {
      _showMessage("Please enter both email and password.", isError: true);
      return;
    }

    final result = await authService.signUp(email, password);
    if (result.user != null) {
      try {
        await storyService.updateLastAccessDate();
      } catch (e) {
        debugPrint("Failed to update last access date: $e");
      }
      _showMessage("Registration successful!", isSuccess: true);
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const HomeScreen()),
      );
    } else {
      _showMessage(result.message, isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    // We'll use LayoutBuilder to compute responsive text sizes
    return Scaffold(
      body: SafeArea(
        child: Stack(
          children: [
            // 1) Background image
            Positioned.fill(
              child: Image.asset(
                "assets/versatale_home_image.png", // Update path to your asset
                fit: BoxFit.cover,
              ),
            ),

            // 2) Small black box with a back arrow in the top-left corner
            Positioned(
              top: 10,
              left: 10,
              child: Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.4),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: IconButton(
                  iconSize: 20,
                  padding: EdgeInsets.zero,
                  icon: const Icon(Icons.arrow_back, color: Colors.white),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ),
            ),

            // 3) Registration form in the center
            LayoutBuilder(
              builder: (context, constraints) {
                final double screenWidth = constraints.maxWidth;
                // Dynamically compute font size, capping at 22
                final double fontSize = min(screenWidth * 0.05, 22.0);

                return Center(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 500),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Title
                          Text(
                            "Create an Account",
                            style: TextStyle(
                              fontSize: fontSize + 4,
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              shadows: const [
                                Shadow(
                                  color: Colors.black,
                                  offset: Offset(1, 1),
                                  blurRadius: 2,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 30),

                          // Email field
                          TextField(
                            controller: emailController,
                            style: TextStyle(
                              fontSize: fontSize,
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                            decoration: InputDecoration(
                              labelText: "Email",
                              labelStyle: TextStyle(
                                fontSize: fontSize * 0.9,
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                shadows: const [
                                  Shadow(
                                    color: Colors.black,
                                    offset: Offset(1, 1),
                                    blurRadius: 2,
                                  ),
                                ],
                              ),
                              filled: true,
                              fillColor: Colors.black.withOpacity(0.4),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                                borderSide: const BorderSide(color: Colors.white),
                              ),
                            ),
                          ),
                          const SizedBox(height: 15),

                          // Password field
                          TextField(
                            controller: passwordController,
                            obscureText: true,
                            style: TextStyle(
                              fontSize: fontSize,
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                            decoration: InputDecoration(
                              labelText: "Password",
                              labelStyle: TextStyle(
                                fontSize: fontSize * 0.9,
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                shadows: const [
                                  Shadow(
                                    color: Colors.black,
                                    offset: Offset(1, 1),
                                    blurRadius: 2,
                                  ),
                                ],
                              ),
                              filled: true,
                              fillColor: Colors.black.withOpacity(0.4),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                                borderSide: const BorderSide(color: Colors.white),
                              ),
                            ),
                          ),
                          const SizedBox(height: 20),

                          // Register button
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.black.withOpacity(0.4),
                                shadowColor: Colors.black,
                                elevation: 8.0,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                side: const BorderSide(
                                  color: Colors.white,
                                  width: 2,
                                ),
                              ),
                              onPressed: register,
                              child: Text(
                                "Register",
                                style: TextStyle(
                                  fontSize: fontSize,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                  shadows: const [
                                    Shadow(
                                      color: Colors.black,
                                      offset: Offset(1, 1),
                                      blurRadius: 2,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
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
