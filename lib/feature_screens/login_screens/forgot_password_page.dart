// lib/screens/forgot_password_page.dart

import 'dart:math';
import 'package:flutter/material.dart';
import '../../widgets/auth_widgets.dart';
import '../../services/auth_service.dart';

class ForgotPasswordPage extends StatefulWidget {
  const ForgotPasswordPage({super.key});

  @override
  _ForgotPasswordPageState createState() => _ForgotPasswordPageState();
}

class _ForgotPasswordPageState extends State<ForgotPasswordPage> {
  final _emailController = TextEditingController();
  final _authService    = AuthService();
  final _formKey        = GlobalKey<FormState>();
  bool _isLoading = false;

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _resetPassword() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    final email = _emailController.text.trim();
    final res   = await _authService.resetPassword(email);

    // assume result.message contains success or error text
    final msg     = res.message;
    final isError = msg.toLowerCase().contains('error');

    showAuthSnackBar(
      context,
      msg,
      background: isError ? Colors.red : Colors.green,
    );

    if (mounted) setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    final w        = MediaQuery.of(context).size.width;
    final fontSize = min(w * 0.05, 22.0);

    return Scaffold(
      body: SafeArea(
        child: Stack(
          children: [
            // Background image
            Positioned.fill(
              child: Image.asset(
                'assets/versatale_home_image.png',
                fit: BoxFit.cover,
              ),
            ),

            // Back button
            const Positioned(
              top: 10,
              left: 10,
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
                          'Reset Password',
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
                        authTextFormField(
                          controller: _emailController,
                          label: 'Email',
                          fontSize: fontSize,
                          validator: (v) =>
                          (v ?? '').isEmpty ? 'Enter email' : null,
                        ),

                        const SizedBox(height: 20),

                        // Submit button
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed:
                            _isLoading ? null : _resetPassword,
                            style: ElevatedButton.styleFrom(
                              backgroundColor:
                              Colors.black.withOpacity(0.4),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                              side: const BorderSide(
                                  color: Colors.white, width: 2),
                            ),
                            child: _isLoading
                                ? const SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                                : Text(
                              'Submit',
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
              ),
            ),
          ],
        ),
      ),
    );
  }
}
