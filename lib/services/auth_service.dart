import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // 🔴 IMPORTANT: Paste your WEB client ID from Firebase Console
  // Firebase Console → Authentication → Sign-in method → Google
  static const String webClientId =
      "530767204970-4lpujiqlt1oun1n12vaukrdr8mqbjgh6.apps.googleusercontent.com";

  Stream<User?> authStateChanges() => _auth.authStateChanges();

  Future<UserCredential?> signInWithGoogle() async {
    try {
      final GoogleSignIn googleSignIn = GoogleSignIn(
        serverClientId: webClientId, // ✅ THIS FIXES YOUR ISSUE
        scopes: ['email'],
      );

      final GoogleSignInAccount? googleUser =
          await googleSignIn.signIn();

      if (googleUser == null) {
        print("Google sign-in cancelled");
        return null;
      }

      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;

      print("accessToken exists: ${googleAuth.accessToken != null}");
      print("idToken exists: ${googleAuth.idToken != null}");

      if (googleAuth.idToken == null) {
        throw Exception(
          "❌ idToken is null → wrong or missing WEB client ID",
        );
      }

      final AuthCredential credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final userCred =
          await _auth.signInWithCredential(credential);

      print("✅ FIREBASE LOGIN OK: ${userCred.user?.email}");
      return userCred;
    } catch (e, st) {
      print("❌ Google sign-in failed: $e");
      print(st);
      rethrow;
    }
  }

  Future<void> signOut() async {
    await GoogleSignIn().signOut();
    await _auth.signOut();
  }
}
