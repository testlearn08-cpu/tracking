import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../services/auth_service.dart';
import '../services/session_service.dart';
import '../core/kolkata_time.dart';
import '../state/timer_controller.dart';
import '../core/widget_bridge.dart';
import '../core/notification_service.dart';

import 'pre_session_screen.dart';
import 'timer_screen.dart';
import 'reports_screen.dart';
import 'settings_screen.dart';
import 'session_history_screen.dart';
import 'session_detail_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key, required this.uid});
  final String uid;

  @override
  Widget build(BuildContext context) {
    final db = FirebaseFirestore.instance;
    final userRef = db.collection('users').doc(uid);
    final today = localDateKolkataYmd();

    return Scaffold(
      appBar: AppBar(
        title: const Text('FocusFlow'),
        actions: [
          IconButton(
            icon: const Icon(Icons.history),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => SessionHistoryScreen(uid: uid)),
            ),
          ),
          IconButton(
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => ReportsScreen(uid: uid)),
            ),
            icon: const Icon(Icons.bar_chart),
          ),
          IconButton(
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => SettingsScreen(uid: uid)),
            ),
            icon: const Icon(Icons.settings),
          ),
        ],
      ),
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: userRef.snapshots(),
        builder: (context, userSnap) {
          // ✅ Show Firestore stream error instead of spinning forever
          if (userSnap.hasError) {
            return _ErrorState(
              title: 'User document stream failed',
              error: userSnap.error,
              hint:
                  'This is usually Firestore rules, wrong Firebase project, or network.',
            );
          }

          // ✅ Show explicit loading state
          if (userSnap.connectionState == ConnectionState.waiting) {
            return const _LoadingState(text: 'Loading user document...');
          }

          if (!userSnap.hasData) {
            return const _LoadingState(text: 'Waiting for user snapshot...');
          }

          final doc = userSnap.data!;
          if (!doc.exists) {
            return _ErrorState(
              title: 'User document missing',
              error: 'Document /users/$uid does not exist.',
              hint:
                  'Your LoginScreen should call _ensureUserDoc after login.\n'
                  'If you recently changed projects/google-services.json, you may be looking at the wrong Firebase project.',
            );
          }

          final u = doc.data() ?? {};
          final goalMinutes = (u['goalMinutes'] as num?)?.toInt() ?? 120;
          final streak = (u['streakCount'] as num?)?.toInt() ?? 0;

          return FutureBuilder<_DashboardData>(
            future: _loadDashboard(db: db, uid: uid, today: today),
            builder: (context, dashSnap) {
              // ✅ Show Future error instead of spinning forever
              if (dashSnap.hasError) {
                return _ErrorState(
                  title: 'Dashboard load failed',
                  error: dashSnap.error,
                  hint:
                      'Common causes:\n'
                      '• Missing Firestore index (query needs composite index)\n'
                      '• Firestore rules (even if you think they are open)\n'
                      '• Network issue on device\n'
                      '• Wrong Firebase project / google-services.json\n',
                );
              }

              if (dashSnap.connectionState == ConnectionState.waiting) {
                return const _LoadingState(text: 'Loading dashboard...');
              }

              if (!dashSnap.hasData) {
                return const _LoadingState(text: 'Waiting for dashboard data...');
              }

              final dash = dashSnap.data!;
              final totalSec = dash.totalFocusSeconds;
              final score = dash.focusScore;
              final sessions = dash.sessions;

              final totalMin = (totalSec / 60).floor();
              final progress = (goalMinutes <= 0)
                  ? 0.0
                  : (totalMin / goalMinutes).clamp(0.0, 1.0);

              // update widget minutes
              WidgetBridge.updateTodayMinutes(totalMin);

              return Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Card(
                            child: Padding(
                              padding: const EdgeInsets.all(12),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('Today',
                                      style: TextStyle(
                                          fontWeight: FontWeight.bold)),
                                  const SizedBox(height: 8),
                                  Text('$totalMin / $goalMinutes min'),
                                  const SizedBox(height: 8),
                                  LinearProgressIndicator(value: progress),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Card(
                            child: Padding(
                              padding: const EdgeInsets.all(12),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('Streak',
                                      style: TextStyle(
                                          fontWeight: FontWeight.bold)),
                                  const SizedBox(height: 8),
                                  Text('🔥 $streak days'),
                                  const SizedBox(height: 8),
                                  Text('Score: $score'),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () => _startFlow(context),
                        child: const Text('Start Focus'),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'Today’s sessions',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Expanded(
                      child: sessions.isEmpty
                          ? const Center(
                              child: Text('No sessions yet. Start one!'))
                          : ListView.separated(
                              itemCount: sessions.length,
                              separatorBuilder: (_, __) =>
                                  const Divider(height: 1),
                              itemBuilder: (_, i) {
                                final s = sessions[i];
                                final id = (s['_id'] ?? '') as String;
                                final intent = (s['intent'] ?? '') as String;
                                final status = (s['status'] ?? '') as String;
                                final actualSec =
                                    ((s['actualFocusSeconds'] ?? 0) as num)
                                        .toInt();
                                final mins = (actualSec / 60).floor();

                                return ListTile(
                                  title: Text(
                                    intent.isEmpty ? '(No intent)' : intent,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  subtitle: Text('$mins min • $status'),
                                  onTap: () => Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => SessionDetailScreen(
                                        uid: uid,
                                        sessionId: id,
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),
                    ),
                    const SizedBox(height: 8),
                    OutlinedButton(
                      onPressed: () => context.read<AuthService>().signOut(),
                      child: const Text('Sign out'),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }

  Future<void> _startFlow(BuildContext context) async {
    final pre = await Navigator.push<PreSessionResult>(
      context,
      MaterialPageRoute(builder: (_) => const PreSessionScreen()),
    );
    if (pre == null) return;

    final sessionService = context.read<SessionService>();
    final started = await sessionService.startSession(
      uid: uid,
      intent: pre.intent,
      category: pre.category,
      presetMinutes: pre.presetMinutes,
      breakMinutes: pre.breakMinutes,
      autoBreak: pre.autoBreak,
    );

    final timer = context.read<TimerController>();
    await timer.startFocus(
      uid: uid,
      sessionId: started.sessionId,
      intent: pre.intent,
      focusSeconds: pre.presetMinutes * 60,
      breakSeconds: pre.breakMinutes * 60,
      autoBreak: pre.autoBreak,
    );

    await NotificationService.instance.cancelAll();
    await NotificationService.instance.scheduleTimerDone(
      id: 1001,
      fromNow: Duration(seconds: pre.presetMinutes * 60),
      title: 'Focus complete ✅',
      body: 'Nice. Log your feedback.',
    );

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => TimerScreen(
          uid: uid,
          sessionId: started.sessionId,
          startedAtEpochMs: started.startedAt.toDate().millisecondsSinceEpoch,
          plannedFocusSeconds: pre.presetMinutes * 60,
        ),
      ),
    );
  }
}

class _DashboardData {
  final int totalFocusSeconds;
  final int focusScore;
  final List<Map<String, dynamic>> sessions;

  _DashboardData({
    required this.totalFocusSeconds,
    required this.focusScore,
    required this.sessions,
  });
}

Future<_DashboardData> _loadDashboard({
  required FirebaseFirestore db,
  required String uid,
  required String today,
}) async {
  // ✅ Add timeouts so "hangs" become visible errors
  const timeout = Duration(seconds: 10);

  final statsRef =
      db.collection('users').doc(uid).collection('dailyStats').doc(today);

  final statsSnap = await statsRef.get().timeout(timeout);
  final stats = statsSnap.data() ?? {};
  final totalSec = ((stats['totalFocusSeconds'] ?? 0) as num).toInt();
  final score = ((stats['focusScore'] ?? 0) as num).toInt();

  final sessionsQ = await db
      .collection('users')
      .doc(uid)
      .collection('sessions')
      .where('localDate', isEqualTo: today)
      .orderBy('startedAt', descending: true)
      .limit(5)
      .get()
      .timeout(timeout);

  final sessions = sessionsQ.docs.map((d) {
    final m = d.data();
    m['_id'] = d.id;
    return m;
  }).toList();

  return _DashboardData(
    totalFocusSeconds: totalSec,
    focusScore: score,
    sessions: sessions,
  );
}

class _LoadingState extends StatelessWidget {
  const _LoadingState({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 12),
            Text(text, textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({
    required this.title,
    required this.error,
    required this.hint,
  });

  final String title;
  final Object? error;
  final String hint;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: Theme.of(context)
                    .textTheme
                    .titleLarge
                    ?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              Text(
                '$error',
                style: const TextStyle(fontFamily: 'monospace'),
              ),
              const SizedBox(height: 12),
              Text(hint),
              const SizedBox(height: 16),
              OutlinedButton(
                onPressed: () {
                  // Quick retry: rebuild this screen
                  (context as Element).markNeedsBuild();
                },
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
