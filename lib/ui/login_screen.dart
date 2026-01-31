import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'home_screen.dart';

import '../services/auth_service.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();

  bool _loading = false;
  bool _hidePassword = true;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

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

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _run(Future<void> Function() action) async {
    setState(() => _loading = true);
    try {
      await action();
    } catch (e) {
      _snack(AuthService.friendlyAuthError(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _handlePostLogin(User user) async {
  await _ensureUserDoc(
    user.uid,
    user.displayName,
    user.email,
    user.photoURL,
  );

  if (!mounted) return;

  Navigator.pushReplacement(
    context,
    MaterialPageRoute(
      builder: (_) => HomeScreen(uid: user.uid),
    ),
  );
}


  @override
  Widget build(BuildContext context) {
    final auth = context.read<AuthService>();

    final googleEnabled = AuthService.enableGoogleSignIn;

    return Scaffold(
      appBar: AppBar(title: const Text('FocusFlow Login')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: _emailCtrl,
                  keyboardType: TextInputType.emailAddress,
                  autofillHints: const [AutofillHints.email],
                  decoration: const InputDecoration(
                    labelText: 'Email',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _passCtrl,
                  obscureText: _hidePassword,
                  autofillHints: const [AutofillHints.password],
                  decoration: InputDecoration(
                    labelText: 'Password',
                    border: const OutlineInputBorder(),
                    suffixIcon: IconButton(
                      onPressed: () =>
                          setState(() => _hidePassword = !_hidePassword),
                      icon: Icon(
                        _hidePassword ? Icons.visibility : Icons.visibility_off,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _loading
                        ? null
                        : () => _run(() async {
                              final email = _emailCtrl.text.trim();
                              final pass = _passCtrl.text;

                              if (email.isEmpty || pass.isEmpty) {
                                _snack('Please enter email and password.');
                                return;
                              }

                              final cred = await auth.signInWithEmailPassword(
                                email: email,
                                password: pass,
                              );

                              final user = cred.user;
                              if (user == null) {
                                throw Exception('FirebaseAuth returned null user.');
                              }

                              await _handlePostLogin(user);
                            }),
                    child: Text(_loading ? 'Please wait…' : 'Sign In'),
                  ),
                ),

                const SizedBox(height: 8),

                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: _loading
                        ? null
                        : () => _run(() async {
                              final email = _emailCtrl.text.trim();
                              final pass = _passCtrl.text;

                              if (email.isEmpty || pass.isEmpty) {
                                _snack('Please enter email and password.');
                                return;
                              }

                              final cred = await auth.signUpWithEmailPassword(
                                email: email,
                                password: pass,
                              );

                              final user = cred.user;
                              if (user == null) {
                                throw Exception('FirebaseAuth returned null user.');
                              }

                              // ✅ Email verification disabled: do nothing extra
                              await _handlePostLogin(user);
                            }),
                    child: const Text('Create Account'),
                  ),
                ),

                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: _loading
                        ? null
                        : () => _run(() async {
                              final email = _emailCtrl.text.trim();
                              if (email.isEmpty) {
                                _snack('Enter your email first.');
                                return;
                              }
                              await auth.sendPasswordResetEmail(email);
                              _snack('Password reset email sent.');
                            }),
                    child: const Text('Forgot password?'),
                  ),
                ),

                const SizedBox(height: 16),

                // ✅ Keep Google button, but disabled for now
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: (_loading || !googleEnabled)
                        ? null
                        : () => _run(() async {
                              final UserCredential? cred =
                                  await auth.signInWithGoogle();

                              if (cred == null) return; // user cancelled

                              final user = cred.user;
                              if (user == null) {
                                throw Exception('FirebaseAuth returned null user.');
                              }

                              await _handlePostLogin(user);
                            }),
                    child: Text(
                      googleEnabled
                          ? 'Continue with Google'
                          : 'Continue with Google (disabled)',
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
