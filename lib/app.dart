import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'services/auth_service.dart';
import 'services/session_service.dart';
import 'services/stats_service.dart';
import 'services/reports_service.dart';
import 'services/export_service.dart';

import 'state/timer_controller.dart';
import 'core/local_timer_store.dart';
import 'core/notification_service.dart';

import 'ui/login_screen.dart';
import 'ui/home_screen.dart';
import 'ui/pre_session_screen.dart';

class FocusFlowApp extends StatefulWidget {
  const FocusFlowApp({super.key, required this.firebaseReady});
  final bool firebaseReady;

  @override
  State<FocusFlowApp> createState() => _FocusFlowAppState();
}

class _FocusFlowAppState extends State<FocusFlowApp> {
  @override
  void initState() {
    super.initState();
    // Safe to init notifications even in web preview; plugin will no-op on web.
    NotificationService.instance.init();
  }

  @override
  Widget build(BuildContext context) {
    // If Firebase isn't ready (common in Codespaces web preview), avoid touching
    // FirebaseAuth/Firestore at all to prevent [core/no-app] errors.
    if (!widget.firebaseReady) {
      return MaterialApp(
        title: 'FocusFlow',
        theme: ThemeData(useMaterial3: true),
        home: const _FirebaseMissingScreen(),
      );
    }

    final db = FirebaseFirestore.instance;

    return MultiProvider(
      providers: [
        Provider<AuthService>(create: (_) => AuthService()),
        Provider<StatsService>(create: (_) => StatsService(db)),
        Provider<ReportsService>(create: (_) => ReportsService(db)),
        Provider<ExportService>(create: (_) => ExportService(db)),
        ProxyProvider<StatsService, SessionService>(
          update: (_, stats, __) => SessionService(db: db, statsService: stats),
        ),
        Provider<TimerController>(
          create: (_) => TimerController(LocalTimerStore())..restoreIfAny(),
        ),
      ],
      child: MaterialApp(
        title: 'FocusFlow',
        theme: ThemeData(useMaterial3: true),
        onGenerateRoute: (settings) {
          // Deep-link style route: /start?preset=25|50|90
          final uri = Uri.tryParse(settings.name ?? '');
          if (uri != null && uri.path == '/start') {
            final preset = int.tryParse(uri.queryParameters['preset'] ?? '');
            return MaterialPageRoute(
              builder: (_) => PreSessionScreen(initialPresetMinutes: preset),
            );
          }
          return null;
        },
        home: StreamBuilder<User?>(
          stream: FirebaseAuth.instance.authStateChanges(),
          builder: (context, snap) {
            final user = snap.data;
            if (user == null) return const LoginScreen();
            return HomeScreen(uid: user.uid);
          },
        ),
      ),
    );
  }
}

class _FirebaseMissingScreen extends StatelessWidget {
  const _FirebaseMissingScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('FocusFlow (Preview)')),
      body: const Padding(
        padding: EdgeInsets.all(16),
        child: Text(
          'Firebase is not configured for Web in this repo yet.\n\n'
          'This is OK — you can continue Android-first development.\n\n'
          'Next steps:\n'
          '1) Configure Firebase for Android (google-services.json)\n'
          '2) Build APK and test on phone\n'
          '3) (Optional) Configure Firebase Web via FlutterFire',
        ),
      ),
    );
  }
}
