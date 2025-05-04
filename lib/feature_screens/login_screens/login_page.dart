import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../widgets/auth_widgets.dart';
import '../../services/auth_service.dart';
import '../../services/story_service.dart';
import '../../theme/theme_notifier.dart';
import '../dashboard_screen.dart';
import 'forgot_password_page.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
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

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);

    final res = await _authSvc.signIn(
      _emailCtrl.text.trim(),
      _pwCtrl.text.trim(),
    );

    if (res.user != null) {
      try {
        final profile = await _storySvc.getUserProfile();
        if (mounted) context.read<ThemeNotifier>().loadFromProfile(profile);
        await _storySvc.updateLastAccessDate();
      } catch (_) {}

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
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return AuthPageShell(
      showBack: true,           // ← back button now visible
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
                  const AuthHeader('VersaTale Login'),
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
                  const SizedBox(height: 5),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      style: TextButton.styleFrom(
                        backgroundColor: cs.surfaceVariant.withOpacity(.6),
                      ),
                      onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const ForgotPasswordPage(),
                        ),
                      ),
                      child: Text(
                        'Forgot Password?',
                        style: tt.labelMedium?.copyWith(
                          color      : cs.onSurface,
                          decoration : TextDecoration.underline,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  AuthActionButton(
                    label   : 'Log In',
                    loading : _loading,
                    onPressed: _login,
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
