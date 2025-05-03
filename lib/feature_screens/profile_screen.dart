// lib/screens/profile_screen.dart

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../services/auth_service.dart';
import '../services/story_service.dart';
import '../theme/theme_notifier.dart';
import '../theme/app_palettes.dart';
import 'login_screens/main_splash_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _authSvc = AuthService();
  final _storySvc = StoryService();

  String _created = '';
  String _lastAcc = '';
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final user = _authSvc.getCurrentUser();
    if (user == null) {
      if (mounted) Navigator.pop(context);
      return;
    }
    try {
      final profile = await _storySvc.getUserProfile();
      context.read<ThemeNotifier>().loadFromProfile(profile);
      setState(() {
        _created = _fmt(profile['creationDate'] ?? '');
        _lastAcc = _fmt(profile['lastAccessDate'] ?? '');
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _fmt(String iso) =>
      DateFormat.yMMMMd().add_jm().format(DateTime.parse(iso).toLocal());

  Future<void> _deleteAccount() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) {
        final cs = Theme.of(context).colorScheme;
        final tt = Theme.of(context).textTheme;
        return AlertDialog(
          title: Text('Delete Account',
              style: tt.titleLarge?.copyWith(color: cs.error)),
          content: Text(
            'Are you sure you want to delete your account? This cannot be undone.',
            style: tt.bodyMedium,
          ),
          actions: [
            TextButton(
              style: TextButton.styleFrom(foregroundColor: cs.secondary),
              onPressed: () => Navigator.pop(context, false),
              child: Text('Cancel', style: tt.labelLarge),
            ),
            TextButton(
              style: TextButton.styleFrom(foregroundColor: cs.error),
              onPressed: () => Navigator.pop(context, true),
              child: Text('Delete', style: tt.labelLarge),
            ),
          ],
        );
      },
    );
    if (ok != true) return;
    try {
      await _storySvc.deleteAllStories();
      await _storySvc.deleteUserData();
      await _authSvc.deleteAccount();
      if (!mounted) return;
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const MainSplashScreen()),
            (_) => false,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  Future<void> _showChangePasswordDialog() async {
    final currentCtrl = TextEditingController();
    final newCtrl = TextEditingController();
    final confirmCtrl = TextEditingController();
    final formKey = GlobalKey<FormState>();

    bool isLoading = false;
    String? error;
    bool showCurrent = false;
    bool showNew = false;
    bool showConfirm = false;

    await showDialog(
      context: context,
      builder: (ctx) {
        final cs = Theme.of(ctx).colorScheme;
        final tt = Theme.of(ctx).textTheme;
        return StatefulBuilder(
          builder: (ctx, setState) => AlertDialog(
            title: Text('Change Password',
                style: tt.titleLarge?.copyWith(color: cs.secondary)),
            content: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (error != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Text(error!,
                          style: tt.bodySmall?.copyWith(color: cs.error)),
                    ),
                  TextFormField(
                    controller: currentCtrl,
                    obscureText: !showCurrent,
                    decoration: InputDecoration(
                      labelText: 'Current Password',
                      labelStyle: tt.bodyMedium,
                      suffixIcon: IconButton(
                        icon: Icon(showCurrent
                            ? Icons.visibility_off
                            : Icons.visibility),
                        onPressed: () =>
                            setState(() => showCurrent = !showCurrent),
                      ),
                    ),
                    validator: (v) =>
                    v == null || v.isEmpty ? 'Enter current password' : null,
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: newCtrl,
                    obscureText: !showNew,
                    decoration: InputDecoration(
                      labelText: 'New Password',
                      labelStyle: tt.bodyMedium,
                      suffixIcon: IconButton(
                        icon: Icon(
                            showNew ? Icons.visibility_off : Icons.visibility),
                        onPressed: () => setState(() => showNew = !showNew),
                      ),
                    ),
                    validator: (v) =>
                    v == null || v.length < 6 ? 'Min 6 characters' : null,
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: confirmCtrl,
                    obscureText: !showConfirm,
                    decoration: InputDecoration(
                      labelText: 'Confirm Password',
                      labelStyle: tt.bodyMedium,
                      suffixIcon: IconButton(
                        icon: Icon(showConfirm
                            ? Icons.visibility_off
                            : Icons.visibility),
                        onPressed: () =>
                            setState(() => showConfirm = !showConfirm),
                      ),
                    ),
                    validator: (v) =>
                    v != newCtrl.text ? 'Passwords do not match' : null,
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                style: TextButton.styleFrom(foregroundColor: cs.secondary),
                onPressed: isLoading ? null : () => Navigator.pop(ctx),
                child: Text('Cancel', style: tt.labelLarge),
              ),
              ElevatedButton(
                onPressed: isLoading
                    ? null
                    : () async {
                  if (!formKey.currentState!.validate()) return;
                  setState(() {
                    isLoading = true;
                    error = null;
                  });
                  final res = await _authSvc.changePassword(
                    currentCtrl.text.trim(),
                    newCtrl.text.trim(),
                  );
                  setState(() => isLoading = false);
                  if (res.user != null) {
                    Navigator.pop(ctx);
                    ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Password updated.')));
                  } else {
                    setState(() => error = res.message);
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: cs.secondary,
                  foregroundColor: cs.onSecondary,
                  textStyle: tt.labelLarge,
                ),
                child: isLoading
                    ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
                    : Text('Change', style: tt.labelLarge),
              ),
            ],
          ),
        );
      },
    );
    // We intentionally do not dispose the controllers here
    // to avoid disposing them while the dialog is still using them.
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final n = context.watch<ThemeNotifier>();

    if (_loading) {
      return Scaffold(
        appBar: AppBar(
          backgroundColor: cs.primary,
          title: Text('User Profile', style: tt.titleLarge?.copyWith(color: cs.onPrimary)),
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final user = _authSvc.getCurrentUser();
    final displayName = (user?.displayName ?? user?.email ?? 'Anonymous')!;

    return Scaffold(
      backgroundColor: cs.background,
      appBar: AppBar(
        backgroundColor: cs.primary,
        title: Text('User Profile', style: tt.titleLarge?.copyWith(color: cs.onPrimary)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            CircleAvatar(
              radius: 48,
              backgroundColor: cs.surface,
              backgroundImage: user?.photoURL != null ? NetworkImage(user!.photoURL!) : null,
              child: user?.photoURL == null
                  ? Icon(Icons.person, size: 48, color: cs.onSurface)
                  : null,
            ),
            const SizedBox(height: 12),
            Text(
              displayName,
              style: tt.titleLarge?.copyWith(color: cs.onBackground),
            ),
            const SizedBox(height: 24),
            _buildSelectors(cs, tt, n),
            const SizedBox(height: 24),
            _metaCard(cs, tt, 'Created On', _created, icon: Icons.calendar_today),
            _metaCard(cs, tt, 'Recorded Last Access Date', _lastAcc, icon: Icons.access_time),
            const SizedBox(height: 24),

            // ——— Change Password Button ———
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 200),
              child: ElevatedButton.icon(
                onPressed: _showChangePasswordDialog,
                icon: const Icon(Icons.lock_outline),
                label: const Text('Change Password'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: cs.secondary,
                  foregroundColor: cs.onSecondary,
                  textStyle: tt.labelLarge,
                ),
              ),
            ),

            const SizedBox(height: 24),

            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 300),
              child: ElevatedButton.icon(
                onPressed: _deleteAccount,
                icon: Icon(Icons.delete_outline, color: cs.error),
                label: Text('Delete Account', style: tt.labelLarge?.copyWith(color: cs.error)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: cs.surface,
                  foregroundColor: cs.error,
                  textStyle: tt.labelLarge,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSelectors(ColorScheme cs, TextTheme tt, ThemeNotifier n) {
    final palettes = kThemes.keys.toList();
    final fonts = kAvailableFonts;
    final currentPalette = palettes.contains(n.currentPalette) ? n.currentPalette : kDefaultPalette;
    final currentFont = fonts.contains(n.currentFont) ? n.currentFont : kDefaultFont;

    return Column(
      children: [
        Card(
          child: ListTile(
            leading: Icon(Icons.color_lens_outlined, color: cs.secondary),
            title: Text('Color Palette', style: tt.bodyMedium),
            trailing: DropdownButton<AppPalette>(
              value: currentPalette,
              onChanged: (p) => n.updatePalette(p!, _storySvc),
              items: palettes
                  .map((p) => DropdownMenuItem(
                value: p,
                child: Text(p.label, style: tt.bodyMedium),
              ))
                  .toList(),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Card(
          child: ListTile(
            leading: Icon(Icons.text_fields, color: cs.secondary),
            title: Text('Font Choice', style: tt.bodyMedium),
            trailing: DropdownButton<String>(
              value: currentFont,
              onChanged: (f) => n.updateFont(f!, _storySvc),
              items: fonts
                  .map((f) => DropdownMenuItem(
                value: f,
                child: Text(f, style: tt.bodyMedium),
              ))
                  .toList(),
            ),
          ),
        ),
      ],
    );
  }

  Widget _metaCard(ColorScheme cs, TextTheme tt, String title, String value,
      {required IconData icon}) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 450),
      child: Card(
        color: cs.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        elevation: 2,
        margin: const EdgeInsets.symmetric(vertical: 8),
        child: ListTile(
          leading: Icon(icon, color: cs.secondary),
          title: Text(title, style: tt.bodyMedium),
          subtitle: Text(value, style: tt.bodySmall),
        ),
      ),
    );
  }
}
