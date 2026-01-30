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
      body: StreamBuilder(
        stream: userRef.snapshots(),
        builder: (context, userSnap) {
          if (!userSnap.hasData) return const Center(child: CircularProgressIndicator());
          final u = userSnap.data!.data() as Map<String, dynamic>? ?? {};
          final goalMinutes = (u['goalMinutes'] as num?)?.toInt() ?? 120;
          final streak = (u['streakCount'] as num?)?.toInt() ?? 0;

          return FutureBuilder(
            future: _loadDashboard(db: db, uid: uid, today: today),
            builder: (context, dashSnap) {
              if (!dashSnap.hasData) return const Center(child: CircularProgressIndicator());
              final dash = dashSnap.data!;

              final totalSec = dash.totalFocusSeconds;
              final score = dash.focusScore;
              final sessions = dash.sessions;

              final totalMin = (totalSec / 60).floor();
              final progress = (goalMinutes <= 0) ? 0.0 : (totalMin / goalMinutes).clamp(0.0, 1.0);

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
                                  const Text('Today', style: TextStyle(fontWeight: FontWeight.bold)),
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
                                  const Text('Streak', style: TextStyle(fontWeight: FontWeight.bold)),
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
                      child: Text('Today’s sessions', style: Theme.of(context).textTheme.titleMedium),
                    ),
                    const SizedBox(height: 8),
                    Expanded(
                      child: sessions.isEmpty
                          ? const Center(child: Text('No sessions yet. Start one!'))
                          : ListView.separated(
                              itemCount: sessions.length,
                              separatorBuilder: (_, __) => const Divider(height: 1),
                              itemBuilder: (_, i) {
                                final s = sessions[i];
                                final id = (s['_id'] ?? '') as String;
                                final intent = (s['intent'] ?? '') as String;
                                final status = (s['status'] ?? '') as String;
                                final actualSec = ((s['actualFocusSeconds'] ?? 0) as num).toInt();
                                final mins = (actualSec / 60).floor();

                                return ListTile(
                                  title: Text(intent.isEmpty ? '(No intent)' : intent,
                                      maxLines: 1, overflow: TextOverflow.ellipsis),
                                  subtitle: Text('$mins min • $status'),
                                  onTap: () => Navigator.push(
                                    context,
                                    MaterialPageRoute(builder: (_) => SessionDetailScreen(uid: uid, sessionId: id)),
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
  final statsRef = db.collection('users').doc(uid).collection('dailyStats').doc(today);
  final statsSnap = await statsRef.get();
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
      .get();

  final sessions = sessionsQ.docs.map((d) {
    final m = d.data();
    m['_id'] = d.id;
    return m;
  }).toList();

  return _DashboardData(totalFocusSeconds: totalSec, focusScore: score, sessions: sessions);
}
