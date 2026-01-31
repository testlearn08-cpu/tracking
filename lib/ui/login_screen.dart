import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../services/auth_service.dart';

class LoginScreen extends StatelessWidget {
  const LoginScreen({super.key});

  Future<void> _ensureUserDoc(
    String uid,
    String? name,
    String? email,
    String? photo,
  ) async {
    final ref = FirebaseFirestore.instance.collection('users').doc(uid);
    final snap = await ref.get();

    if (!snap.exists) {
      await ref.set({
        'name': name ?? '',
        'email': email ?? '',
        'photoUrl': photo ?? '',
        'goalMinutes': 120,
        'mode': 'both',
        'timezone': 'Asia/Kolkata',
        'streakCount': 0,
        'lastGoalMetDate': null,
        'plan': 'free',
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } else {
      await ref.update({'updatedAt': FieldValue.serverTimestamp()});
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.read<AuthService>();

    return Scaffold(
      body: Center(
        child: ElevatedButton(
          onPressed: () async {
            try {
              // ✅ Now returns UserCredential? (nullable)
              final UserCredential? cred = await auth.signInWithGoogle();

              // ✅ User cancelled Google sign-in (back button)
              if (cred == null) return;

              final user = cred.user;

              // ✅ Extremely rare, but handle null user defensively
              if (user == null) {
                throw Exception('FirebaseAuth returned a null user.');
              }

              await _ensureUserDoc(
                user.uid,
                user.displayName,
                user.email,
                user.photoURL,
              );

              // ✅ Optional: navigate after successful login
              // Change '/home' to your actual route if needed
              if (context.mounted) {
                Navigator.pushReplacementNamed(context, '/home');
              }
            } catch (e) {
              // ✅ Show error instead of silent fail
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Google sign-in failed: $e')),
                );
              }
            }
          },
          child: const Text('Continue with Google'),
        ),
      ),
    );
  }
}
