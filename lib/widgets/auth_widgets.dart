// lib/widgets/auth_widgets.dart
import 'package:flutter/material.dart';

/// ───────── Re-usable back arrow ─────────
class AuthBackButton extends StatelessWidget {
  const AuthBackButton({super.key});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      width: 32,
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

/// ───────── Common Input Decoration ─────────
InputDecoration authInputDecoration(BuildContext ctx, String label) {
  final cs = Theme.of(ctx).colorScheme;
  final tt = Theme.of(ctx).textTheme;

  return InputDecoration(
    labelText: label,
    labelStyle: tt.labelLarge?.copyWith(color: cs.onSurface),
    filled: true,
    fillColor: cs.surfaceVariant.withOpacity(.4),
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
  );
}

/// ───────── Styled TextField wrapper ─────────
Widget authTextFormField({
  required BuildContext context,
  required TextEditingController controller,
  required String label,
  bool obscureText = false,
  String? Function(String?)? validator,
}) {
  final tt = Theme.of(context).textTheme;

  return TextFormField(
    controller: controller,
    obscureText: obscureText,
    validator: validator,
    style: tt.bodyLarge?.copyWith(fontWeight: FontWeight.w600),
    decoration: authInputDecoration(context, label),
  );
}

/// ───────── Floating SnackBar ─────────
void showAuthSnackBar(
    BuildContext ctx,
    String message, {
      Color? background,          //  ← restored
    }) {
  final cs = Theme.of(ctx).colorScheme;
  ScaffoldMessenger.of(ctx).showSnackBar(
    SnackBar(
      content: Text(message),
      backgroundColor: background ?? cs.primary,
      behavior: SnackBarBehavior.floating,
    ),
  );
}
