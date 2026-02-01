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

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, required this.uid});
  final String uid;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  // Optimistic UI: show newly-created session immediately
  String? _pendingId; // real sessionId once created, temp id before that
  Map<String, dynamic>? _pendingSession;

  @override
  Widget build(BuildContext context) {
    final db = FirebaseFirestore.instance;
    final userRef = db.collection('users').doc(widget.uid);

    final today = localDateKolkataYmd();
    final statsRef = userRef.collection('dailyStats').doc(today);

    final sessionsQuery = userRef
        .collection('sessions')
        .where('localDate', isEqualTo: today)
        .orderBy('startedAt', descending: true)
        .limit(20);

    return Scaffold(
      appBar: AppBar(
        title: const Text('FocusFlow'),
        backgroundColor: const Color(0xFF0B1220),
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.history),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => SessionHistoryScreen(uid: widget.uid),
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.bar_chart),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => ReportsScreen(uid: widget.uid),
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => SettingsScreen(uid: widget.uid),
              ),
            ),
          ),
          PopupMenuButton<String>(
            onSelected: (v) async {
              if (v == 'signout') {
                await context.read<AuthService>().signOut();
              }
            },
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'signout', child: Text('Sign out')),
            ],
          )
        ],
      ),

      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFF0B1220),
              Color(0xFF070B14),
            ],
          ),
        ),
        child: SafeArea(
          child: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
            stream: userRef.snapshots(),
            builder: (context, userSnap) {
              if (userSnap.hasError) {
                return _ModernError(
                  title: 'User load failed',
                  error: userSnap.error,
                  hint:
                      'Common causes:\n'
                      '• Firestore rules\n'
                      '• Wrong Firebase project / google-services.json\n'
                      '• Network issue\n',
                );
              }

              if (userSnap.connectionState == ConnectionState.waiting) {
                return const _ModernLoading(text: 'Loading user...');
              }

              if (!userSnap.hasData) {
                return const _ModernLoading(text: 'Waiting for user snapshot...');
              }

              final userDoc = userSnap.data!;
              if (!userDoc.exists) {
                return _ModernError(
                  title: 'User document missing',
                  error: 'Document /users/${widget.uid} does not exist.',
                  hint:
                      'Your login should create user doc after sign-in.\n'
                      'If you changed google-services.json, confirm the project.',
                );
              }

              final u = userDoc.data() ?? {};
              final goalMinutes = (u['goalMinutes'] as num?)?.toInt() ?? 120;
              final streak = (u['streakCount'] as num?)?.toInt() ?? 0;

              return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                stream: statsRef.snapshots(),
                builder: (context, statsSnap) {
                  if (statsSnap.hasError) {
                    return _ModernError(
                      title: 'Stats load failed',
                      error: statsSnap.error,
                      hint:
                          'If it mentions index/rules, fix those.\n'
                          'Path: users/${widget.uid}/dailyStats/$today',
                    );
                  }

                  final stats = statsSnap.data?.data() ?? {};
                  final totalSec =
                      ((stats['totalFocusSeconds'] ?? 0) as num).toInt();
                  final score = ((stats['focusScore'] ?? 0) as num).toInt();
                  final totalMin = (totalSec / 60).floor();
                  final progress = (goalMinutes <= 0)
                      ? 0.0
                      : (totalMin / goalMinutes).clamp(0.0, 1.0);

                  // Update home widget safely (can be repeated)
                  WidgetBridge.updateTodayMinutes(totalMin);

                  return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                    stream: sessionsQuery.snapshots(),
                    builder: (context, sessSnap) {
                      if (sessSnap.hasError) {
                        return _ModernError(
                          title: 'Sessions load failed',
                          error: sessSnap.error,
                          hint:
                              'If you see FAILED_PRECONDITION → create Firestore index.\n'
                              'If PERMISSION_DENIED → update Firestore rules.',
                        );
                      }

                      final docs = sessSnap.data?.docs ?? [];

                      // Build a unified list (optimistic item + Firestore items)
                      final sessions =
                          <({String id, Map<String, dynamic> data, bool pending})>[];

                      // 1) optimistic
                      if (_pendingSession != null && _pendingId != null) {
                        final existsInStream = docs.any((d) => d.id == _pendingId);
                        if (!existsInStream) {
                          sessions.add((
                            id: _pendingId!,
                            data: _pendingSession!,
                            pending: true
                          ));
                        } else {
                          // once Firestore contains it, clear pending
                          WidgetsBinding.instance.addPostFrameCallback((_) {
                            if (!mounted) return;
                            setState(() {
                              _pendingSession = null;
                              _pendingId = null;
                            });
                          });
                        }
                      }

                      // 2) firestore
                      for (final d in docs) {
                        sessions.add((id: d.id, data: d.data(), pending: false));
                      }

                      return CustomScrollView(
                        slivers: [
                          SliverToBoxAdapter(
                            child: Padding(
                              padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _HeaderRow(streak: streak, score: score),
                                  const SizedBox(height: 14),
                                  _BigProgressCard(
                                    totalMin: totalMin,
                                    goalMinutes: goalMinutes,
                                    progress: progress,
                                  ),
                                  const SizedBox(height: 14),

                                  const Text(
                                    'Quick start',
                                    style: TextStyle(
                                      color: Colors.white70,
                                      fontWeight: FontWeight.w700,
                                      letterSpacing: 0.2,
                                    ),
                                  ),
                                  const SizedBox(height: 10),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: _QuickStartChip(
                                          labelTop: '25',
                                          labelBottom: 'Pomodoro',
                                          onTap: () => _startFlow(context, presetOverride: 25),
                                        ),
                                      ),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: _QuickStartChip(
                                          labelTop: '50',
                                          labelBottom: 'Custom',
                                          onTap: () => _startFlow(context, presetOverride: 50),
                                        ),
                                      ),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: _QuickStartChip(
                                          labelTop: '90',
                                          labelBottom: 'Long',
                                          onTap: () => _startFlow(context, presetOverride: 90),
                                        ),
                                      ),
                                    ],
                                  ),

                                  const SizedBox(height: 18),
                                  const Text(
                                    'Today’s sessions',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 18,
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                  const SizedBox(height: 10),
                                ],
                              ),
                            ),
                          ),

                          if (sessSnap.connectionState == ConnectionState.waiting &&
                              sessions.isEmpty)
                            const SliverFillRemaining(
                              child: _ModernLoading(text: 'Loading sessions...'),
                            )
                          else if (sessions.isEmpty)
                            const SliverFillRemaining(
                              hasScrollBody: false,
                              child: Center(
                                child: Text(
                                  'No sessions yet. Start one!',
                                  style: TextStyle(color: Colors.white60),
                                ),
                              ),
                            )
                          else
                            SliverList.separated(
                              itemCount: sessions.length,
                              separatorBuilder: (_, __) => const Padding(
                                padding: EdgeInsets.symmetric(horizontal: 16),
                                child: Divider(color: Colors.white10, height: 1),
                              ),
                              itemBuilder: (_, i) {
                                final s = sessions[i];
                                final m = s.data;

                                final intent = (m['intent'] ?? '') as String;
                                final status = (m['status'] ?? '') as String;
                                final actualSec =
                                    ((m['actualFocusSeconds'] ?? 0) as num).toInt();
                                final mins = (actualSec / 60).floor();

                                return Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 16),
                                  child: ListTile(
                                    contentPadding: EdgeInsets.zero,
                                    title: Text(
                                      intent.isEmpty ? '(No intent)' : intent,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                    subtitle: Text(
                                      s.pending
                                          ? 'Saving… • $status'
                                          : '$mins min • $status',
                                      style: const TextStyle(color: Colors.white60),
                                    ),
                                    trailing: s.pending
                                        ? const SizedBox(
                                            width: 18,
                                            height: 18,
                                            child: CircularProgressIndicator(strokeWidth: 2),
                                          )
                                        : const Icon(Icons.chevron_right,
                                            color: Colors.white38),
                                    onTap: s.pending
                                        ? null
                                        : () => Navigator.push(
                                              context,
                                              MaterialPageRoute(
                                                builder: (_) => SessionDetailScreen(
                                                  uid: widget.uid,
                                                  sessionId: s.id,
                                                ),
                                              ),
                                            ),
                                  ),
                                );
                              },
                            ),

                          const SliverToBoxAdapter(child: SizedBox(height: 24)),
                        ],
                      );
                    },
                  );
                },
              );
            },
          ),
        ),
      ),

      floatingActionButton: FloatingActionButton(
        backgroundColor: const Color(0xFF4F46E5),
        onPressed: () => _startFlow(context),
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  Future<void> _startFlow(BuildContext context, {int? presetOverride}) async {
    final pre = await Navigator.push<PreSessionResult>(
      context,
      MaterialPageRoute(
        builder: (_) => PreSessionScreen(initialPresetMinutes: presetOverride),
      ),
    );
    if (pre == null) return;

    // ✅ optimistic insert (shows instantly)
    final tempId = 'pending_${DateTime.now().millisecondsSinceEpoch}';
    setState(() {
      _pendingId = tempId;
      _pendingSession = {
        'intent': pre.intent,
        'status': 'running',
        'actualFocusSeconds': 0,
        'localDate': localDateKolkataYmd(),
      };
    });

    final sessionService = context.read<SessionService>();
    final started = await sessionService.startSession(
      uid: widget.uid,
      intent: pre.intent,
      category: pre.category,
      presetMinutes: pre.presetMinutes,
      breakMinutes: pre.breakMinutes,
      autoBreak: pre.autoBreak,
    );

    // swap temp -> real id (so it disappears once stream contains real doc)
    setState(() {
      _pendingId = started.sessionId;
    });

    final timer = context.read<TimerController>();
    await timer.startFocus(
      uid: widget.uid,
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

    if (!context.mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => TimerScreen(
          uid: widget.uid,
          sessionId: started.sessionId,
          startedAtEpochMs:
              started.startedAt.toDate().millisecondsSinceEpoch,
          plannedFocusSeconds: pre.presetMinutes * 60,
        ),
      ),
    );
  }
}

class _HeaderRow extends StatelessWidget {
  const _HeaderRow({required this.streak, required this.score});
  final int streak;
  final int score;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Text(
          'FocusFlow',
          style: TextStyle(
            color: Colors.white,
            fontSize: 26,
            fontWeight: FontWeight.w900,
            letterSpacing: 0.2,
          ),
        ),
        const Spacer(),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: const Color(0xFF111A2D),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: Colors.white10),
          ),
          child: Row(
            children: [
              const Icon(Icons.local_fire_department,
                  color: Color(0xFFFF8A65), size: 18),
              const SizedBox(width: 6),
              Text(
                '${streak}d',
                style: const TextStyle(
                    color: Colors.white70, fontWeight: FontWeight.w700),
              ),
              const SizedBox(width: 10),
              const Icon(Icons.auto_graph, color: Colors.white60, size: 18),
              const SizedBox(width: 6),
              Text(
                '$score',
                style: const TextStyle(
                    color: Colors.white70, fontWeight: FontWeight.w700),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _BigProgressCard extends StatelessWidget {
  const _BigProgressCard({
    required this.totalMin,
    required this.goalMinutes,
    required this.progress,
  });

  final int totalMin;
  final int goalMinutes;
  final double progress;

  @override
  Widget build(BuildContext context) {
    final left = ((1.0 - progress) * 100).clamp(0, 100).round();

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: Colors.white10),
        boxShadow: const [
          BoxShadow(
            blurRadius: 24,
            color: Colors.black45,
            offset: Offset(0, 10),
          )
        ],
      ),
      child: Row(
        children: [
          SizedBox(
            width: 110,
            height: 110,
            child: Stack(
              alignment: Alignment.center,
              children: [
                SizedBox(
                  width: 110,
                  height: 110,
                  child: CircularProgressIndicator(
                    value: progress,
                    strokeWidth: 10,
                    backgroundColor: Colors.white10,
                    valueColor: const AlwaysStoppedAnimation(Color(0xFF4F46E5)),
                  ),
                ),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '$totalMin',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 26,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const Text(
                      'minutes today',
                      style: TextStyle(color: Colors.white54, fontSize: 12),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Daily goal', style: TextStyle(color: Colors.white60)),
                const SizedBox(height: 6),
                Text(
                  '$goalMinutes min',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 10),
                Text('$left% left', style: const TextStyle(color: Colors.white54)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _QuickStartChip extends StatelessWidget {
  const _QuickStartChip({
    required this.labelTop,
    required this.labelBottom,
    required this.onTap,
  });

  final String labelTop;
  final String labelBottom;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: const Color(0xFF0F172A),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: Colors.white10),
        ),
        child: Column(
          children: [
            Text(
              labelTop,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              labelBottom,
              style: const TextStyle(
                color: Colors.white60,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ModernLoading extends StatelessWidget {
  const _ModernLoading({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(
              width: 34,
              height: 34,
              child: CircularProgressIndicator(strokeWidth: 3),
            ),
            const SizedBox(height: 12),
            Text(text, style: const TextStyle(color: Colors.white60)),
          ],
        ),
      ),
    );
  }
}

class _ModernError extends StatelessWidget {
  const _ModernError({
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
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF0F172A),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: Colors.white10),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 10),
                Text(
                  '$error',
                  style: const TextStyle(
                    color: Colors.white70,
                    fontFamily: 'monospace',
                  ),
                ),
                const SizedBox(height: 10),
                Text(hint, style: const TextStyle(color: Colors.white60)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
