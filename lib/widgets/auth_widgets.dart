import 'dart:math';
import 'package:flutter/material.dart';

/// ───────── Re‑usable back arrow ─────────
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

/// ───────── Common input decoration ─────────
InputDecoration authInputDecoration(BuildContext ctx, String label) {
  final cs = Theme.of(ctx).colorScheme;
  final tt = Theme.of(ctx).textTheme;

  return InputDecoration(
    labelText  : label,
    labelStyle : tt.labelLarge?.copyWith(color: cs.onSurface),
    border     : OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
    enabledBorder: OutlineInputBorder(
      borderSide : BorderSide(color: cs.outlineVariant),
      borderRadius: BorderRadius.circular(8),
    ),
    focusedBorder: OutlineInputBorder(
      borderSide : BorderSide(color: cs.primary, width: 2),
      borderRadius: BorderRadius.circular(8),
    ),
    // ► filled/fillColor now overridden in the field’s build method
    filled    : true,
    fillColor : cs.surfaceVariant.withOpacity(.3),
  );
}

/// ───────── Single‑line text field used by every auth page ─────────
class AuthTextFormField extends StatefulWidget {
  final TextEditingController controller;
  final String   label;
  final String? Function(String?)? validator;
  final bool     isPassword;
  const AuthTextFormField({
    super.key,
    required this.controller,
    required this.label,
    this.validator,
    this.isPassword = false,
  });

  @override
  State<AuthTextFormField> createState() => _AuthTextFormFieldState();
}

class _AuthTextFormFieldState extends State<AuthTextFormField> {
  bool _obscure = true;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onChanged);
  }

  @override
  void didUpdateWidget(covariant AuthTextFormField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_onChanged);
      widget.controller.addListener(_onChanged);
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onChanged);
    super.dispose();
  }

  void _onChanged() => setState(() {});

  @override
  Widget build(BuildContext context) {
    final cs       = Theme.of(context).colorScheme;
    final hasText  = widget.controller.text.isNotEmpty;

    return TextFormField(
      controller : widget.controller,
      validator  : widget.validator,
      obscureText: widget.isPassword ? _obscure : false,
      decoration : authInputDecoration(context, widget.label).copyWith(
        fillColor : cs.surfaceVariant.withOpacity(hasText ? 1.0 : .3),
        suffixIcon: widget.isPassword
            ? IconButton(
          icon : Icon(_obscure
              ? Icons.visibility_off
              : Icons.visibility),
          onPressed: () =>
              setState(() => _obscure = !_obscure),
        )
            : null,
      ),
    );
  }
}

/// ───────── Quick snackbar helper ─────────
void showAuthSnackBar(
    BuildContext context,
    String message, {
      Color? background,
    }) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text(message), backgroundColor: background),
  );
}

/// ───────── Page shell with common background & (optional) back arrow ─────────
class AuthPageShell extends StatelessWidget {
  final Widget child;
  final bool   showBack;
  const AuthPageShell({
    super.key,
    required this.child,
    this.showBack = true,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Stack(
          children: [
            const Positioned.fill(
              child: Image(
                image: AssetImage('assets/versatale_home_image.png'),
                fit  : BoxFit.cover,
              ),
            ),
            if (showBack)
              const Positioned(top: 10, left: 10, child: AuthBackButton()),
            child,
          ],
        ),
      ),
    );
  }
}

/// ───────── Consistent big white headline ─────────
class AuthHeader extends StatelessWidget {
  final String text;
  const AuthHeader(this.text, {super.key});

  @override
  Widget build(BuildContext context) {
    final w  = MediaQuery.sizeOf(context).width;
    final sz = min(w * .05, 22.0) + 4;

    final tt = Theme.of(context).textTheme;
    return Text(
      text,
      style: tt.titleLarge?.copyWith(
        fontSize : sz,
        color    : Colors.white,
        fontWeight: FontWeight.bold,
        shadows  : const [
          Shadow(color: Colors.black, offset: Offset(1, 1), blurRadius: 2),
        ],
      ),
    );
  }
}

/// ───────── Primary “action” button with built‑in loading spinner ─────────
class AuthActionButton extends StatelessWidget {
  final String       label;
  final bool         loading;
  final VoidCallback? onPressed;
  const AuthActionButton({
    super.key,
    required this.label,
    required this.loading,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final w  = MediaQuery.sizeOf(context).width;
    final sz = min(w * .05, 22.0);

    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed : loading ? null : onPressed,
        style     : ElevatedButton.styleFrom(
          backgroundColor: cs.primary.withOpacity(.85),
          foregroundColor: cs.onPrimary,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
        child: loading
            ? const SizedBox(
          width : 24,
          height: 24,
          child : CircularProgressIndicator(strokeWidth: 2),
        )
            : Text(
          label,
          style: tt.labelLarge?.copyWith(
            fontSize  : sz,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}
