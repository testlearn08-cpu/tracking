import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';

import 'app.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // For Android it will succeed once google-services.json is added.
  // For Web, it will fail unless you configure Firebase Web (flutterfire).
  bool firebaseReady = true;
  try {
    await Firebase.initializeApp();
  } catch (e) {
    firebaseReady = false;
    if (kDebugMode) {
      // ignore: avoid_print
      print('Firebase init failed (web preview): $e');
    }
  }

  runApp(FocusFlowApp(firebaseReady: firebaseReady));
}
