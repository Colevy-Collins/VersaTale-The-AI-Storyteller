import 'package:flutter/material.dart';
import 'package:intl/intl.dart'; // For date formatting
import '../services/auth_service.dart';
import '../services/story_service.dart';
import 'login_screens/main_splash_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({Key? key}) : super(key: key);

  @override
  _ProfileScreenState createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final AuthService _authService = AuthService();
  final StoryService _storyService = StoryService();

  String _creationDate = '';
  String _lastAccessDate = '';
  bool _isLoading = true;
  final TextEditingController _passwordController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  String _formatTime(String rawTime) {
    try {
      final dt = DateTime.parse(rawTime).toLocal();
      return DateFormat.yMMMd().add_jm().format(dt);
    } catch (_) {
      return rawTime;
    }
  }

  Future<void> _loadUserData() async {
    final user = _authService.getCurrentUser();
    if (user == null) {
      Navigator.pop(context);
      return;
    }
    try {
      final userData = await _storyService.getUserProfile();
      setState(() {
        _creationDate = _formatTime(userData['creationDate'] ?? '');
        _lastAccessDate = _formatTime(userData['lastAccessDate'] ?? '');
      });
    } catch (e) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text("$e")));
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _updatePassword() async {
    final pw = _passwordController.text.trim();
    if (pw.isEmpty) return;
    final res = await _authService.updatePassword(pw);
    if (res.user == null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text("Failed: ${res.message}")));
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Password successfully updated.")));
      _passwordController.clear();
    }
  }

  Future<void> _deleteAccount() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Confirm Delete"),
        content: const Text("Are you sure you want to delete your account?"),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text("Cancel")),
          TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text("Delete")),
        ],
      ),
    );
    if (confirm != true) return;

    try {
      await _storyService.deleteAllStories();
      await _storyService.deleteUserData();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error clearing data: $e")));
    }
    final res = await _authService.deleteAccount();
    if (res.user != null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text("Error: ${res.message}")));
    } else {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => MainSplashScreen()),
            (r) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = _authService.getCurrentUser();
    final bgColor = Colors.orange.shade50;          // pale orange background
    final barColor = Colors.orange.shade200;        // pale orange app bar
    final accent = Colors.deepPurple.shade300;      // complementary accent
    final darkerAccent = Colors.deepPurple.shade700; // darker purple for key text
    final darkColor = Colors.grey.shade900;         // dark color for text/icons

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: barColor,
        title: const Text(
          "User Profile",
          style: TextStyle(color: Colors.black),
        ),
        elevation: 1,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
        padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // --- Header with Avatar & Name ---
            CircleAvatar(
              radius: 48,
              backgroundColor: Colors.grey.shade200,
              backgroundImage: user?.photoURL != null
                  ? NetworkImage(user!.photoURL!)
                  : null,
              child: user?.photoURL == null
                  ? Icon(Icons.person, size: 48, color: darkColor)
                  : null,
            ),
            const SizedBox(height: 12),
            Text(
              user?.displayName ?? user?.email ?? "Anonymous",
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w600,
                color: darkColor,
              ),
            ),
            const SizedBox(height: 24),

            // --- Account Metadata Card (centered, 450px max) ---
            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 450),
                child: Card(
                  color: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  elevation: 2,
                  margin: const EdgeInsets.symmetric(vertical: 8),
                  child: Column(
                    children: [
                      ListTile(
                        leading: Icon(Icons.calendar_today, color: accent),
                        title: const Text("Created On"),
                        subtitle: Text(
                            _creationDate.isEmpty ? "N/A" : _creationDate),
                      ),
                      const Divider(height: 1),
                      ListTile(
                        leading: Icon(Icons.access_time, color: accent),
                        title: const Text("Last Access"),
                        subtitle: Text(
                            _lastAccessDate.isEmpty ? "N/A" : _lastAccessDate),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            const SizedBox(height: 24),

            // --- Change Password Card (centered, 450px max) ---
            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 500),
                child: Card(
                  color: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  elevation: 2,
                  margin: const EdgeInsets.symmetric(vertical: 8),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        Text(
                          "Change Password",
                          style: Theme.of(context)
                              .textTheme
                              .titleMedium
                              ?.copyWith(color: accent),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: _passwordController,
                          obscureText: true,
                          decoration: InputDecoration(
                            labelText: "New Password",
                            prefixIcon:
                            Icon(Icons.lock_outline, color: accent),
                          ),
                        ),
                        const SizedBox(height: 16),
                        Center(
                          child: ConstrainedBox(
                            constraints:
                            const BoxConstraints(maxWidth: 200),
                            child: ElevatedButton.icon(
                              icon: const Icon(Icons.update),
                              label: const Text(
                                "Update Password",
                                style:
                                TextStyle(color: Colors.black),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: accent,
                                foregroundColor: darkerAccent,
                              ),
                              onPressed: _updatePassword,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 24),

            // --- Delete Account Button (centered, 300px max) ---
            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 300),
                child: ElevatedButton.icon(
                  icon:
                  Icon(Icons.delete_outline, color: darkColor),
                  label: Text(
                    "Delete Account",
                    style: TextStyle(color: darkColor),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.deepPurple.shade700,
                  ),
                  onPressed: _deleteAccount,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
