import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';

import 'app.dart';
import 'core/notification_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

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

  // ✅ Initialize notifications (Android 13 permission request happens here)
  try {
    await NotificationService.instance.init();
  } catch (e) {
    if (kDebugMode) {
      // ignore: avoid_print
      print('Notification init failed: $e');
    }
  }

  runApp(FocusFlowApp(firebaseReady: firebaseReady));
}
