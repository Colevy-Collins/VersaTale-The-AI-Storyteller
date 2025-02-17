import 'package:firebase_auth/firebase_auth.dart';

// Custom result class to hold both user and message
class AuthResult {
  final User? user;
  final String message;

  AuthResult({required this.user, required this.message});
}

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Sign Up
  Future<AuthResult> signUp(String email, String password) async {
    try {
      UserCredential userCredential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      return AuthResult(user: userCredential.user, message: 'Sign up successful!');
    } catch (e) {
      print('Error during sign up: $e');
      return AuthResult(user: null, message: 'Error: ${e.toString()}');
    }
  }

  // Sign In
  Future<AuthResult> signIn(String email, String password) async {
    try {
      UserCredential userCredential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      return AuthResult(user: userCredential.user, message: 'Sign in successful!');
    } catch (e) {
      print('Error during sign in: $e');
      return AuthResult(user: null, message: 'Error: ${e.toString()}');
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
}
