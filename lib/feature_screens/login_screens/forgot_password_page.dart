import 'package:flutter/material.dart';
import '../../widgets/auth_widgets.dart';
import '../../services/auth_service.dart';

class ForgotPasswordPage extends StatefulWidget {
  const ForgotPasswordPage({super.key});
  @override
  State<ForgotPasswordPage> createState() => _ForgotPasswordPageState();
}

class _ForgotPasswordPageState extends State<ForgotPasswordPage> {
  final _emailCtrl = TextEditingController();
  final _authSvc   = AuthService();
  final _formKey   = GlobalKey<FormState>();
  bool _loading    = false;

  @override
  void dispose() {
    _emailCtrl.dispose();
    super.dispose();
  }

  Future<void> _reset() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);

    final res = await _authSvc.resetPassword(_emailCtrl.text.trim());
    final ok  = !res.message.toLowerCase().contains('error');
    showAuthSnackBar(
      context,
      res.message,
      background: ok ? Colors.green : Colors.red,
    );

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
                  const AuthHeader('Reset Password'),
                  const SizedBox(height: 30),
                  AuthTextFormField(
                    controller: _emailCtrl,
                    label     : 'Email',
                    validator : (v) =>
                    (v ?? '').isEmpty ? 'Enter email' : null,
                  ),
                  const SizedBox(height: 20),
                  AuthActionButton(
                    label   : 'Submit',
                    loading : _loading,
                    onPressed: _reset,
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
