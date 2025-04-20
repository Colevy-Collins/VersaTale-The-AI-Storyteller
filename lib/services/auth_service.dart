import 'package:firebase_auth/firebase_auth.dart';

/// Carries back both the Firebase [user] (if any) and a human‐readable [message].
class AuthResult {
  final User? user;
  final String message;

  AuthResult({required this.user, required this.message});
}

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;

  /// Maps FirebaseAuthException codes to user‐friendly strings.
  String _getFriendlyErrorMessage(FirebaseAuthException e) {
    print('FirebaseAuthException: ${e.code} - ${e.message}');
    switch (e.code) {
      case 'invalid-email':
        return 'The email address is not valid. Please check and try again.';
      case 'user-disabled':
        return 'This user has been disabled. Please contact support for assistance.';
      case 'user-not-found':
        return 'No user found with these credentials. Make sure you have the right email/password.';
      case 'wrong-password':
        return 'Incorrect password. Please try again or reset your password.';
      case 'email-already-in-use':
        return 'This email is already registered. Please use a different email, or log in instead.';
      case 'operation-not-allowed':
        return 'This account type is not enabled. Please contact support.';
      case 'weak-password':
        return 'Your password is too weak. Please choose a stronger password.';
      case 'too-many-requests':
        return 'Too many requests have been made from this device. Please wait and try again later.';
      case 'network-request-failed':
        return 'Network error. Please check your internet connection and try again.';
      case 'invalid-credential':
        return 'The provided credential is invalid. Please check and try again.';
      default:
        return 'An unexpected error occurred: ${e.message}';
    }
  }

  /// Central helper that runs any Firebase operation, catches errors,
  /// and wraps the result in [AuthResult].
  Future<AuthResult> _execute<T>(
      Future<T> Function() action, {
        required String successMessage,
        bool returnUser = false,
      }) async {
    try {
      final result = await action();

      // Determine which User to return (if any)
      User? user;
      if (result is UserCredential) {
        user = result.user;
      } else if (returnUser) {
        user = _auth.currentUser;
      }

      return AuthResult(user: user, message: successMessage);
    } on FirebaseAuthException catch (e) {
      // Use our friendly mapping
      return AuthResult(user: null, message: _getFriendlyErrorMessage(e));
    } catch (e) {
      print('Error during auth operation: $e');
      return AuthResult(
        user: null,
        message: 'An unexpected error occurred. Please try again.',
      );
    }
  }

  /// Create a new user account
  Future<AuthResult> signUp(String email, String password) =>
      _execute(
            () => _auth.createUserWithEmailAndPassword(
          email: email,
          password: password,
        ),
        successMessage: 'Sign up successful!',
        returnUser: true,
      );

  /// Sign in existing user
  Future<AuthResult> signIn(String email, String password) =>
      _execute(
            () => _auth.signInWithEmailAndPassword(
          email: email,
          password: password,
        ),
        successMessage: 'Sign in successful!',
        returnUser: true,
      );

  /// Sign out current user
  Future<void> signOut() async {
    await _auth.signOut();
  }

  /// Get the currently signed in user (if any)
  User? getCurrentUser() => _auth.currentUser;

  /// Fetch a fresh Firebase ID token
  Future<String?> getToken() async {
    final user = _auth.currentUser;
    return user != null ? await user.getIdToken() : null;
  }

  /// Send a password reset email
  Future<AuthResult> resetPassword(String email) =>
      _execute(
            () => _auth.sendPasswordResetEmail(email: email),
        successMessage: 'A password reset email has been sent!',
      );

  /// Update the current user’s password
  Future<AuthResult> updatePassword(String newPassword) async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) {
      return AuthResult(user: null, message: 'No user is currently signed in.');
    }
    return _execute(
          () => currentUser.updatePassword(newPassword),
      successMessage: 'Password updated.',
      returnUser: true,
    );
  }

  /// Delete the current user’s account
  Future<AuthResult> deleteAccount() async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) {
      return AuthResult(user: null, message: 'No user is currently signed in.');
    }
    return _execute(
          () => currentUser.delete(),
      successMessage: 'Account deleted.',
    );
  }
}
