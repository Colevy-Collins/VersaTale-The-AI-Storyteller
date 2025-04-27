// lib/screens/profile_screen.dart

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../services/auth_service.dart';
import '../services/story_service.dart';
import '../theme/theme_notifier.dart';
import '../theme/app_palettes.dart';                      // for AppPalette
import 'login_screens/main_splash_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({Key? key}) : super(key: key);

  @override
  _ProfileScreenState createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _authService       = AuthService();
  final _storyService      = StoryService();
  final _passwordController = TextEditingController();

  String _creationDate    = '';
  String _lastAccessDate  = '';
  bool   _isLoading       = true;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  @override
  void dispose() {
    _passwordController.dispose();
    super.dispose();
  }

  String _formatTime(String raw) {
    try {
      return DateFormat.yMMMd().add_jm().format(DateTime.parse(raw).toLocal());
    } catch (_) {
      return raw;
    }
  }

  Future<void> _loadUserData() async {
    final user = _authService.getCurrentUser();
    if (user == null) {
      Navigator.pop(context);
      return;
    }
    try {
      final profile = await _storyService.getUserProfile();
      // Apply saved theme immediately
      context.read<ThemeNotifier>().loadFromProfile(profile);

      setState(() {
        _creationDate   = _formatTime(profile['creationDate'] ?? '');
        _lastAccessDate = _formatTime(profile['lastAccessDate'] ?? '');
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$e'))
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _updatePassword() async {
    final pw = _passwordController.text.trim();
    if (pw.isEmpty) return;
    final res = await _authService.updatePassword(pw);
    if (res.user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed: ${res.message}'))
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Password successfully updated.'))
      );
      _passwordController.clear();
    }
  }

  Future<void> _deleteAccount() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Confirm Delete'),
        content: const Text('Are you sure you want to delete your account?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(context, true),  child: const Text('Delete')),
        ],
      ),
    );
    if (confirm != true) return;

    try {
      await _storyService.deleteAllStories();
      await _storyService.deleteUserData();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error clearing data: $e'))
      );
    }

    final res = await _authService.deleteAccount();
    if (res.user != null) {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: ${res.message}'))
      );
    } else {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const MainSplashScreen()),
            (r) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs       = Theme.of(context).colorScheme;
    final tt       = Theme.of(context).textTheme;
    final notifier = context.watch<ThemeNotifier>();

    Widget themeSelectors() => Column(
      children: [
        Card(
          child: ListTile(
            leading: Icon(Icons.color_lens_outlined, color: cs.primary),
            title: Text('Color Palette', style: tt.bodyMedium),
            trailing: DropdownButton<AppPalette>(
              value: notifier.currentPalette,
              onChanged: (p) => notifier.updatePalette(p!, _storyService),
              items: AppPalette.values
                  .map((p) => DropdownMenuItem(value: p, child: Text(p.name)))
                  .toList(),
            ),
          ),
        ),
        Card(
          child: ListTile(
            leading: Icon(Icons.font_download_outlined, color: cs.primary),
            title: Text('Font Family', style: tt.bodyMedium),
            trailing: DropdownButton<String>(
              value: notifier.currentFont,
              onChanged: (f) => notifier.updateFont(f!, _storyService),
              items: ['Kotta One','Poetsen One','Roboto']
                  .map((f) => DropdownMenuItem(value: f, child: Text(f)))
                  .toList(),
            ),
          ),
        ),
      ],
    );

    if (_isLoading) {
      return Scaffold(
        backgroundColor: cs.background,
        appBar: AppBar(
          backgroundColor: cs.primary,
          title: Text('User Profile', style: tt.titleLarge),
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final user = _authService.getCurrentUser();

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

            // theme selectors
            themeSelectors(),
            const SizedBox(height: 24),

            // Account Metadata
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 450),
              child: Card(
                color: cs.surface,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                elevation: 2,
                margin: const EdgeInsets.symmetric(vertical: 8),
                child: Column(
                  children: [
                    ListTile(
                      leading: Icon(Icons.calendar_today, color: cs.secondary),
                      title: const Text('Created On'),
                      subtitle: Text(_creationDate),
                    ),
                    const Divider(height: 1),
                    ListTile(
                      leading: Icon(Icons.access_time, color: cs.secondary),
                      title: const Text('Last Access'),
                      subtitle: Text(_lastAccessDate),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Change Password
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 500),
              child: Card(
                color: cs.surface,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                elevation: 2,
                margin: const EdgeInsets.symmetric(vertical: 8),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      Text('Change Password', style: tt.titleMedium),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _passwordController,
                        obscureText: true,
                        decoration: InputDecoration(
                          labelText: 'New Password',
                          prefixIcon: Icon(Icons.lock_outline, color: cs.secondary),
                        ),
                      ),
                      const SizedBox(height: 16),
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 200),
                        child: ElevatedButton.icon(
                          icon: const Icon(Icons.update),
                          label: const Text('Update Password'),
                          onPressed: _updatePassword,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: cs.secondary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Delete Account
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 300),
              child: ElevatedButton.icon(
                icon: Icon(Icons.delete_outline, color: cs.error),
                label: const Text('Delete Account'),
                onPressed: _deleteAccount,
                style: ElevatedButton.styleFrom(
                  backgroundColor: cs.surface,
                  foregroundColor: cs.onSurface,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
