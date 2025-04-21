// lib/widgets/auth_widgets.dart

import 'package:flutter/material.dart';

/// A little back‑arrow box
class AuthBackButton extends StatelessWidget {
  const AuthBackButton({super.key});
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 32, height: 32,
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.4),
        borderRadius: BorderRadius.circular(4),
      ),
      child: IconButton(
        padding: EdgeInsets.zero,
        iconSize: 20,
        icon: const Icon(Icons.arrow_back, color: Colors.white),
        onPressed: () => Navigator.of(context).maybePop(),
      ),
    );
  }
}

/// Common input decoration
InputDecoration authInputDecoration(String label, double fontSize) {
  return InputDecoration(
    labelText: label,
    labelStyle: TextStyle(
      fontSize: fontSize * 0.9,
      color: Colors.white,
      fontWeight: FontWeight.bold,
      shadows: const [
        Shadow(color: Colors.black, offset: Offset(1, 1), blurRadius: 2),
      ],
    ),
    filled: true,
    fillColor: Colors.black.withOpacity(0.4),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(8),
    ),
  );
}

/// A wrapper over TextFormField to enforce our style & validation
Widget authTextFormField({
  required TextEditingController controller,
  required String label,
  required double fontSize,
  bool obscureText = false,
  String? Function(String?)? validator,
}) {
  return TextFormField(
    controller: controller,
    obscureText: obscureText,
    validator: validator,
    style: TextStyle(
      fontSize: fontSize,
      color: Colors.white,
      fontWeight: FontWeight.bold,
    ),
    decoration: authInputDecoration(label, fontSize),
  );
}

/// Show a floating snackbar
void showAuthSnackBar(
    BuildContext context,
    String message, {
      Color background = Colors.blue,
    }) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(message),
      backgroundColor: background,
      behavior: SnackBarBehavior.floating,
    ),
  );
}
