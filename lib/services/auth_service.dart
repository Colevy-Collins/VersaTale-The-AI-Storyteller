import 'package:firebase_auth/firebase_auth.dart';

// Custom result class to hold both user and message
class AuthResult {
  final User? user;
  final String message;

  AuthResult({required this.user, required this.message});
}

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;

  /// A helper method to convert FirebaseAuthException codes into user-friendly messages.
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
      // Fallback for any other error code we haven't covered
        return 'An unexpected error occurred: ${e.message}';
    }
  }

  // Sign Up
  Future<AuthResult> signUp(String email, String password) async {
    try {
      UserCredential userCredential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      return AuthResult(
        user: userCredential.user,
        message: 'Sign up successful!',
      );
    } catch (e) {
      print('Error during sign up: $e');
      if (e is FirebaseAuthException) {
        return AuthResult(user: null, message: _getFriendlyErrorMessage(e));
      } else {
        // Non-FirebaseAuthException fallback
        return AuthResult(user: null, message: 'An unexpected error occurred. Please try again.');
      }
    }
  }

  // Sign In
  Future<AuthResult> signIn(String email, String password) async {
    try {
      UserCredential userCredential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      return AuthResult(
        user: userCredential.user,
        message: 'Sign in successful!',
      );
    } catch (e) {
      print('Error during sign in: $e');
      if (e is FirebaseAuthException) {
        return AuthResult(user: null, message: _getFriendlyErrorMessage(e));
      } else {
        // Non-FirebaseAuthException fallback
        return AuthResult(user: null, message: 'An unexpected error occurred. Please try again.');
      }
    }
  }

  // Sign Out
  Future<void> signOut() async {
    await _auth.signOut();
  }

  // Get Current User
  User? getCurrentUser() {
    return _auth.currentUser;
  }

  // Retrieve a fresh Firebase ID token on demand
  Future<String?> getToken() async {
    User? user = _auth.currentUser;
    if (user != null) {
      // This call ensures you get a valid, up-to-date token
      return await user.getIdToken();
    }
    return null;
  }

  // Password Reset
  Future<AuthResult> resetPassword(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email);
      return AuthResult(user: null, message: 'A password reset email has been sent!');
    } catch (e) {
      print('Error during password reset: $e');
      if (e is FirebaseAuthException) {
        return AuthResult(user: null, message: _getFriendlyErrorMessage(e));
      } else {
        // Non-FirebaseAuthException fallback
        return AuthResult(user: null, message: 'An unexpected error occurred. Please try again.');
      }
    }
  }
}
