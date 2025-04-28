// lib/screens/profile_screen.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../services/auth_service.dart';
import '../services/story_service.dart';
import '../theme/theme_notifier.dart';
import '../theme/app_palettes.dart';     // ← gives us kThemes, kAvailableFonts, kDefault*

import 'login_screens/main_splash_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _authSvc  = AuthService();
  final _storySvc = StoryService();
  final _pwCtrl   = TextEditingController();

  String _created = '';
  String _lastAcc = '';
  bool   _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _pwCtrl.dispose();
    super.dispose();
  }

  /* ── helpers ── */

  String _fmt(String raw) {
    try {
      return DateFormat.yMMMd().add_jm().format(DateTime.parse(raw).toLocal());
    } catch (_) {
      return raw;
    }
  }

  Future<void> _load() async {
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
            .showSnackBar(SnackBar(content: Text('$e')));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _updatePw() async {
    final pw = _pwCtrl.text.trim();
    if (pw.isEmpty) return;
    final res = await _authSvc.updatePassword(pw);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(res.user == null
            ? 'Failed: ${res.message}'
            : 'Password updated.'),
      ),
    );
    if (res.user != null) _pwCtrl.clear();
  }

  Future<void> _deleteAccount() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title  : const Text('Confirm Delete'),
        content: const Text('Delete your account permanently?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Delete')),
        ],
      ),
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

  /* ── UI ── */

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final n  = context.watch<ThemeNotifier>();

    /// build the two dropdown cards
    Widget selectors() {
      /* dynamic lists taken from app_palettes.dart */
      final paletteChoices = kThemes.keys.toList();
      final fontChoices    = kAvailableFonts;

      final currentPalette = paletteChoices.contains(n.currentPalette)
          ? n.currentPalette
          : kDefaultPalette;

      final currentFont    = fontChoices.contains(n.currentFont)
          ? n.currentFont
          : kDefaultFont;

      return Column(
        children: [
          Card(
            child: ListTile(
              leading : Icon(Icons.color_lens_outlined, color: cs.primary),
              title   : Text('Color Palette', style: tt.bodyMedium),
              trailing: DropdownButton<AppPalette>(
                value     : currentPalette,
                onChanged : (p) => n.updatePalette(p!, _storySvc),
                items     : paletteChoices
                    .map((p) => DropdownMenuItem(
                    value: p,
                    child: Text(p.label)))
                    .toList(),
              ),
            ),
          ),
          Card(
            child: ListTile(
              leading : Icon(Icons.font_download_outlined, color: cs.primary),
              title   : Text('Font Family', style: tt.bodyMedium),
              trailing: DropdownButton<String>(
                value     : currentFont,
                onChanged : (f) => n.updateFont(f!, _storySvc),
                items     : fontChoices
                    .map((f) => DropdownMenuItem(value: f, child: Text(f)))
                    .toList(),
              ),
            ),
          ),
        ],
      );
    }

    if (_loading) {
      return Scaffold(
        backgroundColor: cs.background,
        appBar: AppBar(
          backgroundColor: cs.primary,
          title: Text('User Profile', style: tt.titleLarge),
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final user = _authSvc.getCurrentUser();

    return Scaffold(
      backgroundColor: cs.background,
      appBar: AppBar(
        backgroundColor: cs.primary,
        title: Text('User Profile', style: tt.titleLarge),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            /* avatar */
            CircleAvatar(
              radius: 48,
              backgroundColor: cs.surface,
              backgroundImage: user?.photoURL != null
                  ? NetworkImage(user!.photoURL!)
                  : null,
              child: user?.photoURL == null
                  ? Icon(Icons.person, size: 48, color: cs.onSurface)
                  : null,
            ),
            const SizedBox(height: 12),
            Text(
              user?.displayName ?? user?.email ?? 'Anonymous',
              style: tt.titleLarge?.copyWith(color: cs.onBackground),
            ),
            const SizedBox(height: 24),

            selectors(),
            const SizedBox(height: 24),

            _metaCard(cs, tt, 'Created On', _created,
                icon: Icons.calendar_today),
            _metaCard(cs, tt, 'Last Access', _lastAcc,
                icon: Icons.access_time),
            const SizedBox(height: 24),

            _passwordCard(cs, tt),
            const SizedBox(height: 24),

            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 300),
              child: ElevatedButton.icon(
                icon : Icon(Icons.delete_outline, color: cs.error),
                label: const Text('Delete Account'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: cs.surface,
                  foregroundColor: cs.onSurface,
                ),
                onPressed: _deleteAccount,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _metaCard(ColorScheme cs, TextTheme tt, String title, String value,
      {required IconData icon}) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 450),
      child: Card(
        color: cs.surface,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12)),
        elevation: 2,
        margin: const EdgeInsets.symmetric(vertical: 8),
        child: ListTile(
          leading : Icon(icon, color: cs.secondary),
          title   : Text(title),
          subtitle: Text(value),
        ),
      ),
    );
  }

  Widget _passwordCard(ColorScheme cs, TextTheme tt) => ConstrainedBox(
    constraints: const BoxConstraints(maxWidth: 500),
    child: Card(
      color: cs.surface,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12)),
      elevation: 2,
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Text('Change Password', style: tt.titleMedium),
            const SizedBox(height: 12),
            TextField(
              controller: _pwCtrl,
              obscureText: true,
              decoration: InputDecoration(
                labelText : 'New Password',
                prefixIcon:
                Icon(Icons.lock_outline, color: cs.secondary),
              ),
            ),
            const SizedBox(height: 16),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 200),
              child: ElevatedButton.icon(
                icon : const Icon(Icons.update),
                label: const Text('Update Password'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: cs.secondary,
                  foregroundColor: cs.onSecondary,
                ),
                onPressed: _updatePw,
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
