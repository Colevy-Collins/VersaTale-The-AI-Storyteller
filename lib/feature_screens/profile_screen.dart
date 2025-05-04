// lib/screens/profile_screen.dart
// -----------------------------------------------------------------------------
// Responsive profile screen:
//  • Tiny devices (~240×340) → stacked layout, dialogs edge‑to‑edge.
//  • Phones → normal Material layout.
//  • Tablets/desktop → centered, max 600px wide.
// 2025‑05‑03
// -----------------------------------------------------------------------------

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../services/auth_service.dart';
import '../services/story_service.dart';
import '../theme/theme_notifier.dart';
import '../theme/app_palettes.dart';
import 'login_screens/main_splash_screen.dart';

/*──────────────────────── constants ───────────────────────*/
const double _kTinyWidth  = 300;
const double _kTinyHeight = 420;
const double _kMaxContentWidth = 600;         // ← comfortable max width column

/* sample policy text — replace with your own */
const String _kPolicyText = '''
**Your Data & Privacy**

We collect only the minimum information needed to create and sync your stories across devices:

- **Email address** (for authentication)  
- **Account creation date**  
- **Last access time**  
- **Chosen theme and font**

You can review all of your profile data on the **Profile** screen, and view your saved stories on the **Story Archive** screen. *(Note: story edit options are not currently available after creation.)*

We **never** sell or share your personal data with third parties.  
If you choose to delete your account, **all** of your data—including profile details and story content—will be permanently removed.

''';

/*=========================================================================*/
/*  Profile Screen                                                         */
/*=========================================================================*/
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});
  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _authSvc  = AuthService();
  final _storySvc = StoryService();

  String _created = '';
  String _lastAcc = '';
  bool   _loading = false;

  /*──────────── lifecycle ────────────*/
  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final user = _authSvc.getCurrentUser();
    if (user == null) { if (mounted) Navigator.pop(context); return; }

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
      iso.isEmpty
          ? ''
          : DateFormat.yMMMMd().add_jm().format(DateTime.parse(iso).toLocal());

  /*──────────── responsive helpers ────────────*/
  bool _isTiny(BoxConstraints c) =>
      c.maxWidth < _kTinyWidth || c.maxHeight < _kTinyHeight;

  EdgeInsets _pagePadding(bool tiny) =>
      tiny ? const EdgeInsets.symmetric(vertical: 16, horizontal: 8)
          : const EdgeInsets.symmetric(vertical: 24, horizontal: 16);

  double _avatarRadius(bool tiny) => tiny ? 32 : 48;

  /*───────────────────── universal adaptive dialog ─────────────────────*/
  Future<void> _showAdaptiveDialog({
    required String title,
    required WidgetBuilder body,
    required List<Widget> actions,
  }) async {
    await showDialog(
      context: context,
      builder: (ctx) => LayoutBuilder(
        builder: (ctx, c) {
          final bool tiny = _isTiny(c);
          const double kMaxW = 560, kMaxH = 600;
          final double w = c.maxWidth  < kMaxW ? c.maxWidth * .95  : kMaxW;
          final double h = c.maxHeight < kMaxH ? c.maxHeight * .85 : kMaxH;

          return Dialog(
            insetPadding: EdgeInsets.zero,
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: w, maxHeight: h),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Padding(
                    padding: EdgeInsets.fromLTRB(
                        tiny ? 16 : 24, tiny ? 16 : 20, tiny ? 16 : 24, 12),
                    child: Text(title,
                        textAlign: TextAlign.center,
                        style: tiny
                            ? Theme.of(ctx).textTheme.titleMedium
                            : Theme.of(ctx).textTheme.titleLarge),
                  ),
                  const Divider(height: 1),
                  Expanded(child: SingleChildScrollView(child: body(ctx))),
                  const Divider(height: 1),
                  Padding(
                    padding: EdgeInsets.symmetric(
                        horizontal: tiny ? 4 : 8, vertical: tiny ? 4 : 8),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: actions,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  /*───────────────────── dialogs ─────────────────────*/
  Future<void> _showDataPolicyDialog() =>
      _showAdaptiveDialog(
        title: 'Data Collection Policy',
        body: (_) => Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: SelectableText(_kPolicyText,
              style: Theme.of(context).textTheme.bodyMedium),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      );

  Future<void> _showChangePasswordDialog() async {
    final currentCtrl = TextEditingController();
    final newCtrl     = TextEditingController();
    final confirmCtrl = TextEditingController();
    final formKey     = GlobalKey<FormState>();

    bool   isLoading = false;
    String? error;
    bool showCurrent = false;
    bool showNew     = false;
    bool showConfirm = false;

    await _showAdaptiveDialog(
      title: 'Change Password',
      body: (ctx) {
        final cs = Theme.of(ctx).colorScheme;
        final tt = Theme.of(ctx).textTheme;
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
          child: Form(
            key: formKey,
            child: Column(
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
                    suffixIcon: IconButton(
                      icon: Icon(
                          showCurrent ? Icons.visibility_off : Icons.visibility),
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
        );
      },
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        StatefulBuilder(
          builder: (ctx, setSt) => ElevatedButton(
            onPressed: isLoading
                ? null
                : () async {
              if (!formKey.currentState!.validate()) return;
              setSt(() {
                isLoading = true;
                error = null;
              });
              final res = await _authSvc.changePassword(
                currentCtrl.text.trim(),
                newCtrl.text.trim(),
              );
              setSt(() => isLoading = false);
              if (res.user != null) {
                if (mounted) {
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Password updated.')));
                }
              } else {
                setSt(() => error = res.message);
              }
            },
            child: isLoading
                ? const SizedBox(
                width: 16, height: 16, child: CircularProgressIndicator())
                : const Text('Change'),
          ),
        ),
      ],
    );
  }

  Future<void> _deleteAccount() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        final cs = Theme.of(ctx).colorScheme;
        final tt = Theme.of(ctx).textTheme;
        return AlertDialog(
          title: Text('Delete Account',
              style: tt.titleLarge?.copyWith(color: cs.error)),
          content: Text('Are you sure? This cannot be undone.',
              style: tt.bodyMedium),
          actions: [
            TextButton(
              style: TextButton.styleFrom(foregroundColor: cs.secondary),
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel'),
            ),
            TextButton(
              style: TextButton.styleFrom(foregroundColor: cs.error),
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Delete'),
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

  /*──────────────────────── BUILD ────────────────────────*/
  @override
  Widget build(BuildContext context) {
    final n  = context.watch<ThemeNotifier>();
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    final user        = _authSvc.getCurrentUser();
    final displayName = (user?.displayName ?? user?.email ?? 'Anonymous')!;

    if (_loading) {
      return Scaffold(
        appBar: AppBar(
          backgroundColor: cs.primary,
          title: Text('User Profile',
              style: tt.titleLarge?.copyWith(color: cs.onPrimary)),
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return LayoutBuilder(builder: (ctx, c) {
      final bool tiny = _isTiny(c);

      return Scaffold(
        backgroundColor: cs.background,
        appBar: AppBar(
          backgroundColor: cs.primary,
          title: Text('User Profile',
              style: tt.titleLarge?.copyWith(color: cs.onPrimary)),
        ),
        body: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: _kMaxContentWidth),
            child: SingleChildScrollView(
              padding: _pagePadding(tiny),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  /*──────── avatar & name ────────*/
                  CircleAvatar(
                    radius: _avatarRadius(tiny),
                    backgroundColor: cs.surface,
                    backgroundImage: user?.photoURL != null
                        ? NetworkImage(user!.photoURL!)
                        : null,
                    child: user?.photoURL == null
                        ? Icon(Icons.person,
                        size: _avatarRadius(tiny), color: cs.onSurface)
                        : null,
                  ),
                  SizedBox(height: tiny ? 8 : 12),
                  Text(displayName,
                      style: tiny
                          ? tt.titleMedium?.copyWith(color: cs.onBackground)
                          : tt.titleLarge?.copyWith(color: cs.onBackground)),
                  const SizedBox(height: 16),

                  /*──────── selectors ───────────*/
                  _buildSelectors(cs, tt, n, tiny),
                  const SizedBox(height: 16),

                  /*──────── meta cards ──────────*/
                  _metaCard(cs, tt, 'Created On', _created,
                      icon: Icons.calendar_today, tiny: tiny),
                  _metaCard(cs, tt, 'Recorded Last Access Date', _lastAcc,
                      icon: Icons.access_time, tiny: tiny),
                  const SizedBox(height: 16),

                  /*──────── action buttons ──────*/
                  SizedBox(
                    width: tiny ? double.infinity : 220,
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
                  const SizedBox(height: 12),
                  SizedBox(
                    width: tiny ? double.infinity : 240,
                    child: OutlinedButton.icon(
                      onPressed: _showDataPolicyDialog,
                      icon: Icon(Icons.privacy_tip_outlined, color: cs.secondary),
                      label: const Text('Data Collection Policy'),
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: tiny ? double.infinity : 260,
                    child: ElevatedButton.icon(
                      onPressed: _deleteAccount,
                      icon: Icon(Icons.delete_outline, color: cs.error),
                      label: Text('Delete Account',
                          style: tt.labelLarge?.copyWith(color: cs.error)),
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
          ),
        ),
      );
    });
  }

  /*──────────────────── helper widgets ───────────────────*/
  Widget _buildSelectors(
      ColorScheme cs, TextTheme tt, ThemeNotifier n, bool tiny) {
    final palettes    = kThemes.keys.toList();
    final fonts       = kAvailableFonts;
    final currentPal  = palettes.contains(n.currentPalette)
        ? n.currentPalette
        : kDefaultPalette;
    final currentFont = fonts.contains(n.currentFont)
        ? n.currentFont
        : kDefaultFont;

    Widget selectorCard<T>({
      required IconData icon,
      required String  label,
      required T       value,
      required List<DropdownMenuItem<T>> items,
      required ValueChanged<T?> onChanged,
    }) {
      if (tiny) {
        return Card(
          margin: const EdgeInsets.symmetric(vertical: 4),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(icon, color: cs.secondary, size: 18),
                    const SizedBox(width: 6),
                    Text(label, style: tt.bodySmall),
                  ],
                ),
                const SizedBox(height: 4),
                DropdownButtonHideUnderline(
                  child: DropdownButton<T>(
                    isDense   : true,
                    isExpanded: true,
                    value     : value,
                    onChanged : onChanged,
                    items     : items,
                  ),
                ),
              ],
            ),
          ),
        );
      } else {
        return Card(
          margin: const EdgeInsets.symmetric(vertical: 8),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: ListTile(
            leading: Icon(icon, color: cs.secondary, size: 24),
            title  : Text(label, style: tt.bodyMedium),
            trailing: SizedBox(
              width: 160,
              child: DropdownButtonHideUnderline(
                child: DropdownButton<T>(
                  isDense: true,
                  value  : value,
                  onChanged: onChanged,
                  items: items,
                ),
              ),
            ),
          ),
        );
      }
    }

    return Column(
      children: [
        selectorCard<AppPalette>(
          icon : Icons.color_lens_outlined,
          label: 'Color Palette',
          value: currentPal,
          items: palettes
              .map((p) => DropdownMenuItem(
            value: p,
            child: Text(p.label,
                style: tiny ? tt.bodySmall : tt.bodyMedium),
          ))
              .toList(),
          onChanged: (p) => n.updatePalette(p!, _storySvc),
        ),
        selectorCard<String>(
          icon : Icons.text_fields,
          label: 'Font Choice',
          value: currentFont,
          items: fonts
              .map((f) => DropdownMenuItem(
            value: f,
            child: Text(f,
                style: tiny ? tt.bodySmall : tt.bodyMedium),
          ))
              .toList(),
          onChanged: (f) => n.updateFont(f!, _storySvc),
        ),
      ],
    );
  }

  Widget _metaCard(ColorScheme cs, TextTheme tt, String title, String value,
      {required IconData icon, required bool tiny}) {
    return Card(
      margin: EdgeInsets.symmetric(vertical: tiny ? 4 : 8),
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(tiny ? 8 : 12)),
      child: ListTile(
        dense: tiny,
        contentPadding: EdgeInsets.symmetric(
            horizontal: tiny ? 8 : 16, vertical: tiny ? 4 : 8),
        leading: Icon(icon, color: cs.secondary, size: tiny ? 18 : 24),
        title: Text(title,
            style: tiny ? tt.bodySmall : tt.bodyMedium,
            overflow: TextOverflow.ellipsis),
        subtitle: Text(value,
            style:
            tiny ? tt.bodySmall?.copyWith(fontSize: 10) : tt.bodySmall,
            overflow: TextOverflow.ellipsis),
      ),
    );
  }
}
