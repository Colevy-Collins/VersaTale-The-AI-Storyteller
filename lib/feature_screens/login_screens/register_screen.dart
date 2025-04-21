// lib/screens/register_screen.dart

import 'dart:math';
import 'package:flutter/material.dart';
import '../../widgets/auth_widgets.dart';
import '../../services/auth_service.dart';
import '../../services/story_service.dart';
import '../dashboard_screen.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});
  @override
  _RegisterScreenState createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _emailController    = TextEditingController();
  final _passwordController = TextEditingController();
  final _authService        = AuthService();
  final _storyService       = StoryService();
  final _formKey            = GlobalKey<FormState>();
  bool _isLoading = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _register() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    final res = await _authService.signUp(
      _emailController.text.trim(),
      _passwordController.text.trim(),
    );

    if (res.user != null) {
      try {
        await _storyService.updateLastAccessDate();
      } catch (_) {}
      showAuthSnackBar(context, 'Registration successful!', background: Colors.green);
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const HomeScreen()),
      );
    } else {
      showAuthSnackBar(context, res.message, background: Colors.red);
    }

    if (mounted) setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    final w = MediaQuery.of(context).size.width;
    final fontSize = min(w * 0.05, 22.0);

    return Scaffold(
      body: SafeArea(
        child: Stack(
          children: [
            // Background
            Positioned.fill(
              child: Image.asset(
                'assets/versatale_home_image.png',
                fit: BoxFit.cover,
              ),
            ),
            // Back button
            const Positioned(
              top: 10, left: 10,
              child: AuthBackButton(),
            ),
            // Form
            Form(
              key: _formKey,
              child: Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 500),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Create an Account',
                          style: TextStyle(
                            fontSize: fontSize + 4,
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            shadows: const [
                              Shadow(
                                  color: Colors.black,
                                  offset: Offset(1, 1),
                                  blurRadius: 2),
                            ],
                          ),
                        ),
                        const SizedBox(height: 30),
                        authTextFormField(
                          controller: _emailController,
                          label: 'Email',
                          fontSize: fontSize,
                          validator: (v) => (v ?? '').isEmpty ? 'Enter email' : null,
                        ),
                        const SizedBox(height: 15),
                        authTextFormField(
                          controller: _passwordController,
                          label: 'Password',
                          fontSize: fontSize,
                          obscureText: true,
                          validator: (v) => (v ?? '').isEmpty ? 'Enter password' : null,
                        ),
                        const SizedBox(height: 20),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: _isLoading ? null : _register,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.black.withOpacity(0.4),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8)),
                              side: const BorderSide(color: Colors.white, width: 2),
                            ),
                            child: _isLoading
                                ? const SizedBox(
                              width: 24, height: 24,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white),
                            )
                                : Text(
                              'Register',
                              style: TextStyle(
                                fontSize: fontSize,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                                shadows: const [
                                  Shadow(
                                      color: Colors.black,
                                      offset: Offset(1, 1),
                                      blurRadius: 2),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
