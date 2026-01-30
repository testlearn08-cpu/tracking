import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/auth_service.dart';

class LoginScreen extends StatelessWidget {
  const LoginScreen({super.key});

  Future<void> _ensureUserDoc(String uid, String? name, String? email, String? photo) async {
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
            final cred = await auth.signInWithGoogle();
            final u = cred.user!;
            await _ensureUserDoc(u.uid, u.displayName, u.email, u.photoURL);
          },
          child: const Text('Continue with Google'),
        ),
      ),
    );
  }
}
