// lib/widgets/auth_widgets.dart
import 'package:flutter/material.dart';

/// ─────────────────────────────────────────────────────────────────────────
///  BACK‑ARROW used on all auth screens
/// ─────────────────────────────────────────────────────────────────────────
class AuthBackButton extends StatelessWidget {
  const AuthBackButton({super.key});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      width : 32,
      height: 32,
      decoration: BoxDecoration(
        color: cs.surfaceVariant.withOpacity(.6),
        borderRadius: BorderRadius.circular(4),
      ),
      child: IconButton(
        padding: EdgeInsets.zero,
        iconSize: 20,
        icon: Icon(Icons.arrow_back, color: cs.onSurface),
        onPressed: () => Navigator.of(context).maybePop(),
      ),
    );
  }
}

/// ─────────────────────────────────────────────────────────────────────────
///  RE‑USABLE SnackBar helper
/// ─────────────────────────────────────────────────────────────────────────
void showAuthSnackBar(
    BuildContext ctx,
    String message, {
      Color? background,
    }) {
  final cs = Theme.of(ctx).colorScheme;
  ScaffoldMessenger.of(ctx).showSnackBar(
    SnackBar(
      content        : Text(message),
      backgroundColor: background ?? cs.primary,
      behavior       : SnackBarBehavior.floating,
    ),
  );
}

/// ─────────────────────────────────────────────────────────────────────────
///  DEFAULT decoration (pulled into its own function so both widgets share it)
/// ─────────────────────────────────────────────────────────────────────────
InputDecoration _decoration(BuildContext ctx, String label,
    {Color? fillColor, Widget? suffixIcon}) {
  final cs = Theme.of(ctx).colorScheme;
  final tt = Theme.of(ctx).textTheme;

  return InputDecoration(
    labelText : label,
    labelStyle: tt.labelLarge?.copyWith(color: cs.onSurface),
    filled    : true,
    fillColor : fillColor ?? cs.surfaceVariant.withOpacity(.4),
    suffixIcon: suffixIcon,
    border    : OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
  );
}

/// ─────────────────────────────────────────────────────────────────────────
///  NEW  ►  AuthTextFormField
///         * Pass `isPassword:true` to get the eye‑icon toggle
///         * Field background becomes solid when it contains text
/// ─────────────────────────────────────────────────────────────────────────
class AuthTextFormField extends StatefulWidget {
  const AuthTextFormField({
    super.key,
    required this.controller,
    required this.label,
    this.validator,
    this.isPassword = false,
  });

  final TextEditingController      controller;
  final String                     label;
  final FormFieldValidator<String>? validator;
  final bool                       isPassword;

  @override
  State<AuthTextFormField> createState() => _AuthTextFormFieldState();
}

class _AuthTextFormFieldState extends State<AuthTextFormField> {
  late bool _obscure;     // only used when isPassword == true

  @override
  void initState() {
    super.initState();
    _obscure = widget.isPassword;                    // start hidden for pw
    widget.controller.addListener(() {
      if (mounted) setState(() {});                  // repaint when text changes
    });
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return TextFormField(
      controller : widget.controller,
      validator  : widget.validator,
      obscureText: widget.isPassword ? _obscure : false,
      style      : tt.bodyLarge?.copyWith(fontWeight: FontWeight.w600),
      decoration : _decoration(
        context,
        widget.label,
        fillColor: widget.controller.text.isEmpty
            ? cs.surfaceVariant.withOpacity(.6)      // translucent
            : cs.surfaceVariant,                     // solid when not empty
        suffixIcon: widget.isPassword
            ? IconButton(
          icon : Icon(
            _obscure ? Icons.visibility : Icons.visibility_off,
          ),
          tooltip : _obscure ? 'Show password' : 'Hide password',
          onPressed: () => setState(() => _obscure = !_obscure),
        )
            : null,
      ),
    );
  }
}

/// ─────────────────────────────────────────────────────────────────────────
///  (OPTIONAL) LEGACY helper kept for non‑password simple inputs
///             – use AuthTextFormField everywhere if you prefer
/// ─────────────────────────────────────────────────────────────────────────
Widget authTextFormField({
  required BuildContext context,
  required TextEditingController controller,
  required String label,
  bool obscureText = false,
  String? Function(String?)? validator,
}) {
  final tt = Theme.of(context).textTheme;
  final cs = Theme.of(context).colorScheme;

  return TextFormField(
    controller : controller,
    obscureText: obscureText,
    validator  : validator,
    style      : tt.bodyLarge?.copyWith(fontWeight: FontWeight.w600),
    decoration : _decoration(
      context,
      label,
      fillColor: cs.surfaceVariant.withOpacity(.4),
    ),
  );
}
