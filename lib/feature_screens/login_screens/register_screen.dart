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
  bool _loading    = false;

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
    return AuthPageShell(
      child: Form(
        key: _formKey,
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 500),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const AuthHeader('Create an Account'),
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
                    isPassword: true,
                    validator : (v) =>
                    (v ?? '').isEmpty ? 'Enter password' : null,
                  ),
                  const SizedBox(height: 20),
                  AuthActionButton(
                    label   : 'Register',
                    loading : _loading,
                    onPressed: _register,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
