import 'package:flutter/material.dart';
import 'package:intl/intl.dart'; // For date formatting
import '../services/auth_service.dart';
import '../services/story_service.dart';
import 'main_splash_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({Key? key}) : super(key: key);

  @override
  _ProfileScreenState createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final AuthService _authService = AuthService();
  final StoryService _storyService = StoryService();

  // Removed _emailController since change email is no longer needed.
  final TextEditingController _passwordController = TextEditingController();

  // We’ll store the user’s Firestore metadata here once loaded.
  String _creationDate = '';
  String _lastAccessDate = '';

  // Loading flag
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  /// Format a date string (ISO8601) into a user-friendly string.
  /// Returns empty string if parsing fails.
  String _formatTime(String rawTime) {
    try {
      // Parse the UTC time, convert it to local time, and format it.
      DateTime dateTime = DateTime.parse(rawTime).toLocal();
      return DateFormat.yMMMd().add_jm().format(dateTime);
    } catch (e) {
      return rawTime;
    }
  }

  /// Loads the current user's profile from Firestore (creation date, last access).
  Future<void> _loadUserData() async {
    final user = _authService.getCurrentUser();
    if (user == null) {
      // No authenticated user; navigate back or handle the error.
      Navigator.pop(context);
      return;
    }
    try {
      // Fetch user’s metadata from Firestore via story_service.
      final userData = await _storyService.getUserProfile();
      setState(() {
        _creationDate = _formatTime(userData['creationDate'] ?? '');
        _lastAccessDate = _formatTime(userData['lastAccessDate'] ?? '');
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("$e")),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  /// Updates the user’s password via Firebase Auth.
  Future<void> _updatePassword() async {
    final newPassword = _passwordController.text.trim();
    if (newPassword.isEmpty) return;

    final result = await _authService.updatePassword(newPassword);
    if (result.user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Failed to update password: ${result.message}")),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Password successfully updated.")),
      );
      _passwordController.clear();
    }
  }

  /// Deletes the user’s account from Firebase and any data from Firestore.
  Future<void> _deleteAccount() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Confirm Delete"),
        content: const Text("Are you sure you want to delete your account?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text("Cancel"),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text("Delete"),
          ),
        ],
      ),
    );

    if (confirm == true) {
      // Optionally remove the user's Firestore data and stories first.
      try {
        await _storyService.deleteAllStories();
        await _storyService.deleteUserData();
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error clearing user data: $e")),
        );
      }

      // Call the delete account method from AuthService.
      final result = await _authService.deleteAccount();
      if (result.user != null) {
        // If deletion did not succeed, show an error message.
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error deleting account: ${result.message}")),
        );
      } else {
        // Deletion was successful: redirect the user to the main splash page.
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => MainSplashScreen()),
              (route) => false,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("User Profile"),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
        padding: const EdgeInsets.all(16),
        child: SingleChildScrollView(
          child: Column(
            children: [
              // Creation Date Display
              ListTile(
                title: const Text("Creation Date"),
                subtitle: Text(_creationDate.isEmpty ? "N/A" : _creationDate),
              ),
              // Last Access Date Display
              ListTile(
                title: const Text("Last Access Date"),
                subtitle: Text(_lastAccessDate.isEmpty ? "N/A" : _lastAccessDate),
              ),
              const Divider(),
              // Change Password
              TextField(
                controller: _passwordController,
                decoration: const InputDecoration(labelText: "New Password"),
                obscureText: true,
              ),
              const SizedBox(height: 8),
              ElevatedButton(
                onPressed: _updatePassword,
                child: const Text("Update Password"),
              ),
              const SizedBox(height: 24),
              // Delete Account
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                onPressed: _deleteAccount,
                child: const Text("Delete Account"),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
