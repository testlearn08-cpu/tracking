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

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, required this.uid});
  final String uid;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  /// If Firestore takes time to reflect writes (rare but can happen with cache/network),
  /// we show the created session immediately as a "pending" card.
  final Map<String, _PendingSession> _pending = {};

  /// So we can refresh UI while the timer is running/paused.
  late final TimerController _timer;

  StreamSubscription<int>? _tickerSub;

  @override
  void initState() {
    super.initState();

    _timer = context.read<TimerController>();

    // Restore active timer (if app was killed / reopened)
    // Safe to call multiple times.
    _timer.restoreIfAny().then((_) {
      if (mounted) setState(() {});
    });

    // Rebuild home when ticker updates (so banner/button labels update)
    _tickerSub = _timer.remainingStream.listen((_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _tickerSub?.cancel();
    super.dispose();
  }

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
        .limit(30);

    return Scaffold(
      backgroundColor: const Color(0xFF070B14),
      appBar: AppBar(
        title: const Text('FocusFlow'),
        backgroundColor: const Color(0xFF0B1220),
        actions: [
          IconButton(
            icon: const Icon(Icons.history),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => SessionHistoryScreen(uid: widget.uid)),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.bar_chart),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => ReportsScreen(uid: widget.uid)),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => SettingsScreen(uid: widget.uid)),
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
            colors: [Color(0xFF0B1220), Color(0xFF070B14)],
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
                  hint: 'Check Firestore rules / correct Firebase project / network.',
                );
              }
              if (!userSnap.hasData) return const _ModernLoading(text: 'Loading user...');

              final userDoc = userSnap.data!;
              if (!userDoc.exists) {
                return _ModernError(
                  title: 'User document missing',
                  error: 'Document /users/${widget.uid} does not exist.',
                  hint:
                      'Ensure you create /users/{uid} after sign-in.\n'
                      'Also confirm google-services.json belongs to the same project.',
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
                      hint: 'Stats path: users/${widget.uid}/dailyStats/$today',
                    );
                  }

                  final stats = statsSnap.data?.data() ?? {};
                  final baseTotalSec = ((stats['totalFocusSeconds'] ?? 0) as num).toInt();

                  // ✅ Live add current running focus seconds (UI-only, not stored)
                  int liveExtraSec = 0;
                  final a = _timer.active;
                  if (a != null &&
                      a.uid == widget.uid &&
                      a.phase == TimerPhase.focusing &&
                      a.status == TimerStatus.running) {
                    final rem = a.remainingSeconds();
                    final elapsed = a.phaseDurationSeconds - rem;
                    if (elapsed > 0) liveExtraSec = elapsed;
                  }

                  final totalSec = baseTotalSec + liveExtraSec;
                  final totalMin = (totalSec / 60).floor();

                  final progress =
                      (goalMinutes <= 0) ? 0.0 : (totalMin / goalMinutes).clamp(0.0, 1.0);

                  // Home widget update (safe to call repeatedly)
                  WidgetBridge.updateTodayMinutes(totalMin);

                  return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                    stream: sessionsQuery.snapshots(),
                    builder: (context, sessSnap) {
                      if (sessSnap.hasError) {
                        return _ModernError(
                          title: 'Sessions load failed',
                          error: sessSnap.error,
                          hint:
                              'If FAILED_PRECONDITION => create Firestore index.\n'
                              'If PERMISSION_DENIED => update Firestore rules.',
                        );
                      }

                      final docs = sessSnap.data?.docs ?? [];

                      // If Firestore stream contains any pending ids, remove them from pending.
                      if (docs.isNotEmpty && _pending.isNotEmpty) {
                        final ids = docs.map((e) => e.id).toSet();
                        final toRemove = <String>[];
                        for (final k in _pending.keys) {
                          if (ids.contains(k)) toRemove.add(k);
                        }
                        if (toRemove.isNotEmpty) {
                          WidgetsBinding.instance.addPostFrameCallback((_) {
                            if (!mounted) return;
                            setState(() {
                              for (final k in toRemove) {
                                _pending.remove(k);
                              }
                            });
                          });
                        }
                      }

                      final hasData = sessSnap.hasData;

                      return Column(
                        children: [
                          Expanded(
                            child: CustomScrollView(
                              slivers: [
                                SliverToBoxAdapter(
                                  child: Padding(
                                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        _HeaderRow(streak: streak),
                                        const SizedBox(height: 14),

                                        // Resume banner if timer exists
                                        if (_timer.active != null) ...[
                                          _ActiveTimerBanner(
                                            timer: _timer,
                                            onResume: () => _resumeActiveTimer(context),
                                            onEnd: () => _endActiveTimerFromHome(context),
                                          ),
                                          const SizedBox(height: 14),
                                        ],

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
                                                labelBottom: 'Short',
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
                                            fontWeight: FontWeight.w800,
                                          ),
                                        ),
                                        const SizedBox(height: 10),
                                      ],
                                    ),
                                  ),
                                ),

                                // Pending session cards first (optimistic)
                                if (_pending.isNotEmpty)
                                  SliverList(
                                    delegate: SliverChildBuilderDelegate(
                                      (context, index) {
                                        final item = _pending.values.toList()[index];
                                        return Padding(
                                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                                          child: _PendingSessionCard(item: item),
                                        );
                                      },
                                      childCount: _pending.length,
                                    ),
                                  ),

                                if (!hasData)
                                  const SliverFillRemaining(
                                    child: _ModernLoading(text: 'Loading sessions...'),
                                  )
                                else if (docs.isEmpty && _pending.isEmpty)
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
                                    itemCount: docs.length,
                                    separatorBuilder: (_, __) => const Padding(
                                      padding: EdgeInsets.symmetric(horizontal: 16),
                                      child: Divider(color: Colors.white10, height: 1),
                                    ),
                                    itemBuilder: (_, i) {
                                      final d = docs[i];
                                      final m = d.data();
                                      final id = d.id;

                                      final intent = (m['intent'] ?? '') as String;
                                      final status = (m['status'] ?? '') as String;
                                      final actualSec = ((m['actualFocusSeconds'] ?? 0) as num).toInt();
                                      final mins = (actualSec / 60).floor();

                                      return Padding(
                                        padding: const EdgeInsets.symmetric(horizontal: 16),
                                        child: ListTile(
                                          contentPadding: const EdgeInsets.symmetric(horizontal: 0),
                                          title: Text(
                                            intent.isEmpty ? '(No intent)' : intent,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
                                          ),
                                          subtitle: Text(
                                            '$mins min • $status',
                                            style: const TextStyle(color: Colors.white60),
                                          ),
                                          trailing: const Icon(Icons.chevron_right, color: Colors.white38),
                                          onTap: () => Navigator.push(
                                            context,
                                            MaterialPageRoute(
                                              builder: (_) => SessionDetailScreen(uid: widget.uid, sessionId: id),
                                            ),
                                          ),
                                        ),
                                      );
                                    },
                                  ),

                                const SliverToBoxAdapter(child: SizedBox(height: 14)),
                              ],
                            ),
                          ),

                          // Bottom CTA
                          Padding(
                            padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
                            child: SizedBox(
                              width: double.infinity,
                              height: 54,
                              child: ElevatedButton(
                                onPressed: () => _startFlow(context),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF4F46E5),
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                  elevation: 0,
                                ),
                                child: const Text(
                                  'START FOCUS',
                                  style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 0.8),
                                ),
                              ),
                            ),
                          ),
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
    // If a timer is already active, don’t create a second session
    if (_timer.active != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('You already have an active timer. Resume or end it first.')),
      );
      return;
    }

    final pre = await Navigator.push<PreSessionResult>(
      context,
      MaterialPageRoute(builder: (_) => PreSessionScreen(initialPresetMinutes: presetOverride)),
    );
    if (pre == null) return;

    final sessionService = context.read<SessionService>();

    // Optimistic: create pending card immediately
    final tempKey = DateTime.now().millisecondsSinceEpoch.toString();
    setState(() {
      _pending[tempKey] = _PendingSession(
        id: tempKey,
        intent: pre.intent,
        status: 'creating...',
        createdAt: DateTime.now(),
      );
    });

    try {
      final started = await sessionService.startSession(
        uid: widget.uid,
        intent: pre.intent,
        category: pre.category,
        presetMinutes: pre.presetMinutes,
        breakMinutes: pre.breakMinutes,
        autoBreak: pre.autoBreak,
      );

      // Replace pending temp with real session id (until Firestore stream shows it)
      if (!mounted) return;
      setState(() {
        _pending.remove(tempKey);
        _pending[started.sessionId] = _PendingSession(
          id: started.sessionId,
          intent: pre.intent,
          status: 'running',
          createdAt: DateTime.now(),
        );
      });

      await _timer.startFocus(
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
            startedAtEpochMs: started.startedAt.toDate().millisecondsSinceEpoch,
            plannedFocusSeconds: pre.presetMinutes * 60,
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _pending.remove(tempKey));
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to start session: $e')),
      );
    }
  }

  /// ✅ FIX: Resume uses Firestore session.startedAt (authoritative), not phaseStartEpochMs.
  Future<void> _resumeActiveTimer(BuildContext context) async {
    final a = _timer.active;
    if (a == null) return;

    // If break is active, you can route to BreakScreen later.
    if (a.phase == TimerPhase.breakTime) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Break is active. Open break in your timer flow.')),
      );
      return;
    }

    try {
      final ref = FirebaseFirestore.instance
          .collection('users')
          .doc(widget.uid)
          .collection('sessions')
          .doc(a.sessionId);

      final snap = await ref.get();
      final data = snap.data() ?? {};

      final startedAt = (data['startedAt'] as Timestamp?)?.toDate();
      final presetMinutes = ((data['presetMinutes'] ?? 0) as num).toInt();

      final startedEpochMs =
          (startedAt ?? DateTime.now()).millisecondsSinceEpoch;

      final plannedFocusSeconds =
          (presetMinutes > 0 ? presetMinutes * 60 : a.focusSeconds);

      if (!context.mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => TimerScreen(
            uid: widget.uid,
            sessionId: a.sessionId,
            startedAtEpochMs: startedEpochMs,
            plannedFocusSeconds: plannedFocusSeconds,
          ),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to resume: $e')),
      );
    }
  }

  /// ✅ FIX: End active timer uses Firestore startedAt for correct actualFocusSeconds.
  Future<void> _endActiveTimerFromHome(BuildContext context) async {
    final a = _timer.active;
    if (a == null) return;

    final sessionService = context.read<SessionService>();

    try {
      final ref = FirebaseFirestore.instance
          .collection('users')
          .doc(widget.uid)
          .collection('sessions')
          .doc(a.sessionId);

      final snap = await ref.get();
      final data = snap.data() ?? {};
      final startedAt = (data['startedAt'] as Timestamp?)?.toDate() ??
          DateTime.fromMillisecondsSinceEpoch(a.phaseStartEpochMs);

      final presetMinutes = ((data['presetMinutes'] ?? 0) as num).toInt();
      final plannedFocusSeconds =
          presetMinutes > 0 ? presetMinutes * 60 : a.focusSeconds;

      // Stop notifications/timer immediately
      await NotificationService.instance.cancelAll();
      await _timer.clear();

      // Mark cancelled in Firestore using correct startedAt
      await sessionService.endSession(
        uid: widget.uid,
        sessionId: a.sessionId,
        startedAt: startedAt,
        plannedFocusSeconds: plannedFocusSeconds,
        endedNormally: false,
        totalPausedSeconds: a.totalPausedSeconds,
      );

      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Session cancelled.')),
      );
      setState(() {});
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to cancel: $e')),
      );
    }
  }
}

/* ---------------- UI COMPONENTS ---------------- */

class _HeaderRow extends StatelessWidget {
  const _HeaderRow({required this.streak});
  final int streak;

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
              const Icon(Icons.local_fire_department, color: Color(0xFFFF8A65), size: 18),
              const SizedBox(width: 6),
              Text(
                '${streak}d streak',
                style: const TextStyle(color: Colors.white70, fontWeight: FontWeight.w700),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ActiveTimerBanner extends StatelessWidget {
  const _ActiveTimerBanner({
    required this.timer,
    required this.onResume,
    required this.onEnd,
  });

  final TimerController timer;
  final VoidCallback onResume;
  final VoidCallback onEnd;

  String _fmt(int s) {
    final x = s < 0 ? 0 : s;
    final m = (x ~/ 60).toString().padLeft(2, '0');
    final r = (x % 60).toString().padLeft(2, '0');
    return '$m:$r';
  }

  @override
  Widget build(BuildContext context) {
    final a = timer.active!;
    final remaining = a.remainingSeconds();
    final status = a.status == TimerStatus.paused ? 'Paused' : 'Running';

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white10),
      ),
      child: Row(
        children: [
          const Icon(Icons.timer, color: Colors.white70),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  a.intent,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 4),
                Text(
                  '$status • ${_fmt(remaining)} left',
                  style: const TextStyle(color: Colors.white60),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          TextButton(
            onPressed: onEnd,
            child: const Text('End', style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.w800)),
          ),
          const SizedBox(width: 6),
          ElevatedButton(
            onPressed: onResume,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF4F46E5),
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('Resume', style: TextStyle(fontWeight: FontWeight.w900)),
          ),
        ],
      ),
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
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: Colors.white10),
        boxShadow: const [
          BoxShadow(
            blurRadius: 24,
            spreadRadius: 0,
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
                    color: const Color(0xFF4F46E5),
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
                    const Text('minutes today', style: TextStyle(color: Colors.white54, fontSize: 12)),
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
                  style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 10),
                Text(
                  '${((1.0 - progress) * 100).round()}% left',
                  style: const TextStyle(color: Colors.white54),
                ),
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
            Text(labelTop, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w900)),
            const SizedBox(height: 4),
            Text(labelBottom, style: const TextStyle(color: Colors.white60, fontSize: 12, fontWeight: FontWeight.w700)),
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
            const SizedBox(width: 34, height: 34, child: CircularProgressIndicator(strokeWidth: 3)),
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
                Text(title, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w900)),
                const SizedBox(height: 10),
                Text('$error', style: const TextStyle(color: Colors.white70, fontFamily: 'monospace')),
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

/* ---------------- Pending session model/card ---------------- */

class _PendingSession {
  final String id;
  final String intent;
  final String status;
  final DateTime createdAt;

  _PendingSession({
    required this.id,
    required this.intent,
    required this.status,
    required this.createdAt,
  });
}

class _PendingSessionCard extends StatelessWidget {
  const _PendingSessionCard({required this.item});
  final _PendingSession item;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white10),
      ),
      child: Row(
        children: [
          const SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF4F46E5)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.intent,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 4),
                Text(
                  item.status,
                  style: const TextStyle(color: Colors.white60),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
