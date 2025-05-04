import 'dart:math';
import 'package:flutter/material.dart';

import '../../widgets/auth_widgets.dart';
import '../../services/auth_service.dart';
import '../../services/story_service.dart';
import '../dashboard_screen.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _emailCtrl = TextEditingController();
  final _pwCtrl    = TextEditingController();
  final _authSvc   = AuthService();
  final _storySvc  = StoryService();
  final _formKey   = GlobalKey<FormState>();

  bool _loading = false;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _pwCtrl.dispose();
    super.dispose();
  }

  Future<void> _register() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);

    final res = await _authSvc.signUp(
      _emailCtrl.text.trim(),
      _pwCtrl.text.trim(),
    );

    if (res.user != null) {
      try { await _storySvc.updateLastAccessDate(); } catch (_) {}
      showAuthSnackBar(
        context,
        'Registration successful!',
        background: Colors.green,
      );
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const HomeScreen()),
      );
    } else {
      showAuthSnackBar(context, res.message, background: Colors.red);
    }

    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    final w   = MediaQuery.of(context).size.width;
    final sz  = min(w * .05, 22.0);           // responsive label size
    final cs  = Theme.of(context).colorScheme;
    final tt  = Theme.of(context).textTheme;

    return Scaffold(
      body: SafeArea(
        child: Stack(
          children: [
            Positioned.fill(
              child: Image.asset('assets/versatale_home_image.png',
                  fit: BoxFit.cover),
            ),
            const Positioned(top: 10, left: 10, child: AuthBackButton()),

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
                          style: tt.titleLarge?.copyWith(
                            fontSize : sz + 4,
                            color    : Colors.white,
                            fontWeight: FontWeight.bold,
                            shadows  : const [
                              Shadow(
                                color: Colors.black,
                                offset: Offset(1, 1),
                                blurRadius: 2,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 30),

                        AuthTextFormField(
                          controller: _emailCtrl,
                          label     : 'Email',
                          validator : (v) =>
                          (v ?? '').isEmpty ? 'Enter email' : null,
                        ),
                        const SizedBox(height: 15),

                        AuthTextFormField(
                          controller: _pwCtrl,
                          label     : 'Password',
                          isPassword: true,                 // 👈 show / hide
                          validator : (v) =>
                          (v ?? '').isEmpty ? 'Enter password' : null,
                        ),
                        const SizedBox(height: 20),

                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed : _loading ? null : _register,
                            style     : ElevatedButton.styleFrom(
                              backgroundColor: cs.primary.withOpacity(.85),
                              foregroundColor: cs.onPrimary,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            child: _loading
                                ? const SizedBox(
                              width : 24,
                              height: 24,
                              child : CircularProgressIndicator(
                                strokeWidth: 2,
                              ),
                            )
                                : Text(
                              'Register',
                              style: tt.labelLarge?.copyWith(
                                fontSize  : sz,
                                fontWeight: FontWeight.bold,
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
