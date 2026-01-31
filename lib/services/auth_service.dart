import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // 🔴 IMPORTANT: Paste your WEB client ID from Firebase Console
  // Firebase Console → Authentication → Sign-in method → Google
  static const String webClientId =
      "530767204970-4lpujiqlt1oun1n12vaukrdr8mqbjgh6.apps.googleusercontent.com";

  // ✅ TEMP: disable Google Sign-In button/flow without deleting code
  // Set to true later when you want to re-enable Google.
  static const bool enableGoogleSignIn = false;

  Stream<User?> authStateChanges() => _auth.authStateChanges();
  User? get currentUser => _auth.currentUser;

  // ---------------------------
  // ✅ EMAIL / PASSWORD AUTH
  // ---------------------------

  Future<UserCredential> signInWithEmailPassword({
    required String email,
    required String password,
  }) async {
    return await _auth.signInWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
  }

  Future<UserCredential> signUpWithEmailPassword({
    required String email,
    required String password,
  }) async {
    // ✅ Email verification is disabled (per your requirement)
    return await _auth.createUserWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
  }

  Future<void> sendPasswordResetEmail(String email) async {
    await _auth.sendPasswordResetEmail(email: email.trim());
  }

  // ---------------------------
  // ✅ GOOGLE SIGN-IN (disabled via flag)
  // ---------------------------

  Future<UserCredential?> signInWithGoogle() async {
    if (!enableGoogleSignIn) {
      throw Exception('Google Sign-In is temporarily disabled.');
    }

    try {
      final GoogleSignIn googleSignIn = GoogleSignIn(
        serverClientId: webClientId,
        scopes: ['email'],
      );

      final GoogleSignInAccount? googleUser = await googleSignIn.signIn();

      if (googleUser == null) {
        // user cancelled
        return null;
      }

      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;

      if (googleAuth.idToken == null) {
        throw Exception("idToken is null → wrong or missing WEB client ID");
      }

      final AuthCredential credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final userCred = await _auth.signInWithCredential(credential);
      return userCred;
    } catch (e, st) {
      // Keep your logging style
      // ignore: avoid_print
      print("❌ Google sign-in failed: $e");
      // ignore: avoid_print
      print(st);
      rethrow;
    }
  }

  // ---------------------------
  // ✅ SIGN OUT
  // ---------------------------

  Future<void> signOut() async {
    // Only attempt Google sign-out if enabled (avoid unnecessary calls)
    if (enableGoogleSignIn) {
      await GoogleSignIn().signOut();
    }
    await _auth.signOut();
  }

  // ---------------------------
  // ✅ FRIENDLY ERROR MESSAGES
  // ---------------------------

  static String friendlyAuthError(Object e) {
    if (e is FirebaseAuthException) {
      switch (e.code) {
        case 'invalid-email':
          return 'Invalid email address.';
        case 'user-disabled':
          return 'This account has been disabled.';
        case 'user-not-found':
          return 'No user found for this email.';
        case 'wrong-password':
          return 'Incorrect password.';
        case 'email-already-in-use':
          return 'This email is already registered.';
        case 'weak-password':
          return 'Password is too weak (min 6 characters).';
        case 'operation-not-allowed':
          return 'Email/Password sign-in is not enabled in Firebase.';
        case 'too-many-requests':
          return 'Too many attempts. Try again later.';
        default:
          return e.message ?? 'Auth error: ${e.code}';
      }
    }
    return 'Something went wrong. Please try again.';
  }
}
