// lib/services/auth_service.dart

import 'package:firebase_auth/firebase_auth.dart';

/// Wraps a Firebase User (if any) together with a human‐readable [message].
class AuthResult {
  final User? user;
  final String message;

  AuthResult({required this.user, required this.message});
}

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;

  /// Convert FirebaseAuthException codes into friendly messages.
  String _getFriendlyErrorMessage(FirebaseAuthException e) {
    switch (e.code) {
      case 'invalid-email':
        return 'The email address is not valid. Please check and try again.';
      case 'user-disabled':
        return 'This user has been disabled. Please contact support.';
      case 'user-not-found':
        return 'No account found with those credentials.';
      case 'wrong-password':
        return 'Incorrect password.';
      case 'email-already-in-use':
        return 'An account already exists with that email.';
      case 'operation-not-allowed':
        return 'This sign-in method is not enabled.';
      case 'weak-password':
        return 'The password is too weak.';
      case 'too-many-requests':
        return 'Too many attempts. Please wait and try again later.';
      case 'network-request-failed':
        return 'Network error. Check your connection.';
      default:
        return e.message ?? 'Authentication error. Please try again.';
    }
  }

  /// Helper to run a Firebase action, catch errors, and return an AuthResult.
  Future<AuthResult> _execute<T>(
      Future<T> Function() action, {
        required String successMessage,
        bool returnUser = false,
      }) async {
    try {
      final result = await action();
      User? user;
      if (result is UserCredential) {
        user = result.user;
      } else if (returnUser) {
        user = _auth.currentUser;
      }
      return AuthResult(user: user, message: successMessage);
    } on FirebaseAuthException catch (e) {
      return AuthResult(user: null, message: _getFriendlyErrorMessage(e));
    } catch (e) {
      return AuthResult(
          user: null, message: 'An unexpected error occurred.');
    }
  }

  /// Create a new account.
  Future<AuthResult> signUp(String email, String password) =>
      _execute(
            () => _auth.createUserWithEmailAndPassword(
          email: email,
          password: password,
        ),
        successMessage: 'Sign up successful!',
        returnUser: true,
      );

  /// Sign in an existing user.
  Future<AuthResult> signIn(String email, String password) =>
      _execute(
            () => _auth.signInWithEmailAndPassword(
          email: email,
          password: password,
        ),
        successMessage: 'Sign in successful!',
        returnUser: true,
      );

  /// Sign out.
  Future<void> signOut() async {
    await _auth.signOut();
  }

  /// Get currently signed-in user.
  User? getCurrentUser() => _auth.currentUser;

  /// Get fresh ID token.
  Future<String?> getToken() async {
    final user = _auth.currentUser;
    return user != null ? await user.getIdToken() : null;
  }

  /// Send a reset-password email.
  Future<AuthResult> resetPassword(String email) =>
      _execute(
            () => _auth.sendPasswordResetEmail(email: email),
        successMessage: 'Password reset email sent.',
      );

  /// Change password, requiring current password for re-authentication.
  Future<AuthResult> changePassword(
      String currentPassword, String newPassword) async {
    final user = _auth.currentUser;
    if (user == null) {
      return AuthResult(user: null, message: 'No user is signed in.');
    }
    final email = user.email;
    if (email == null) {
      return AuthResult(
          user: null, message: 'User has no email on record.');
    }

    // Re-authenticate:
    try {
      final cred = EmailAuthProvider.credential(
        email: email,
        password: currentPassword,
      );
      await user.reauthenticateWithCredential(cred);
    } on FirebaseAuthException catch (e) {
      if (e.code == 'wrong-password') {
        return AuthResult(
          user: null,
          message: 'Current password is incorrect.',
        );
      }
      return AuthResult(user: null, message: _getFriendlyErrorMessage(e));
    } catch (_) {
      return AuthResult(
          user: null, message: 'An unexpected error occurred.');
    }

    // If successful, update to the new password:
    return _execute(
          () => user.updatePassword(newPassword),
      successMessage: 'Password updated successfully.',
      returnUser: true,
    );
  }

  /// Update password directly (no re-auth).
  Future<AuthResult> updatePassword(String newPassword) async {
    final user = _auth.currentUser;
    if (user == null) {
      return AuthResult(user: null, message: 'No user is signed in.');
    }
    return _execute(
          () => user.updatePassword(newPassword),
      successMessage: 'Password updated successfully.',
      returnUser: true,
    );
  }

  /// Delete the current user's account.
  Future<AuthResult> deleteAccount() async {
    final user = _auth.currentUser;
    if (user == null) {
      return AuthResult(user: null, message: 'No user is signed in.');
    }
    return _execute(
          () => user.delete(),
      successMessage: 'Account deleted.',
    );
  }
}
