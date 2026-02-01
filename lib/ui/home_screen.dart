// lib/ui/home_screen.dart
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
  // Colors (modern “CSS-like” look)
  static const _bgTop = Color(0xFF0B1220);
  static const _bgBottom = Color(0xFF070B14);
  static const _card = Color(0xFF0F172A);
  static const _card2 = Color(0xFF111A2D);
  static const _accent = Color(0xFF6C63FF);

  Future<void> _startFlow(BuildContext context, {int? presetOverride}) async {
    final pre = await Navigator.push<PreSessionResult>(
      context,
      MaterialPageRoute(
        builder: (_) => PreSessionScreen(initialPresetMinutes: presetOverride),
      ),
    );
    if (pre == null) return;

    final sessionService = context.read<SessionService>();
    final started = await sessionService.startSession(
      uid: widget.uid,
      intent: pre.intent,
      category: pre.category,
      presetMinutes: pre.presetMinutes,
      breakMinutes: pre.breakMinutes,
      autoBreak: pre.autoBreak,
    );

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

    if (!mounted) return;
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
  }

  @override
  Widget build(BuildContext context) {
    final db = FirebaseFirestore.instance;
    final uid = widget.uid;

    final userRef = db.collection('users').doc(uid);
    final today = localDateKolkataYmd();
    final statsRef = userRef.collection('dailyStats').doc(today);

    // ✅ IMPORTANT:
    // Avoid composite-index requirement by NOT using orderBy with where(localDate == today).
    // We sort client-side so sessions appear instantly after creation.
    final sessionsQuery = userRef.collection('sessions').where('localDate', isEqualTo: today).limit(50);

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        titleSpacing: 16,
        title: const Text(
          'FocusFlow',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
        actions: [
          IconButton(
            tooltip: 'History',
            icon: const Icon(Icons.history),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => SessionHistoryScreen(uid: uid)),
            ),
          ),
          IconButton(
            tooltip: 'Reports',
            icon: const Icon(Icons.bar_chart),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => ReportsScreen(uid: uid)),
            ),
          ),
          IconButton(
            tooltip: 'Settings',
            icon: const Icon(Icons.settings),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => SettingsScreen(uid: uid)),
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
          ),
          const SizedBox(width: 8),
        ],
      ),
      extendBodyBehindAppBar: true,
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [_bgTop, _bgBottom],
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
                  hint: 'Usually Firestore rules / wrong project / network.',
                );
              }
              if (!userSnap.hasData) {
                return const _ModernLoading(text: 'Loading user...');
              }

              final userDoc = userSnap.data!;
              if (!userDoc.exists) {
                return _ModernError(
                  title: 'User document missing',
                  error: 'Document /users/$uid does not exist.',
                  hint:
                      'Your login should create the user doc after sign-in (ensureUserDoc).\n'
                      'If you changed google-services.json, confirm you are on the correct Firebase project.',
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
                      hint: 'Stats doc path: users/$uid/dailyStats/$today',
                    );
                  }

                  final stats = statsSnap.data?.data() ?? {};
                  final totalSec = ((stats['totalFocusSeconds'] ?? 0) as num).toInt();
                  final score = ((stats['focusScore'] ?? 0) as num).toInt();
                  final totalMin = (totalSec / 60).floor();
                  final progress = (goalMinutes <= 0) ? 0.0 : (totalMin / goalMinutes).clamp(0.0, 1.0);

                  // Widget update (safe to call repeatedly)
                  WidgetBridge.updateTodayMinutes(totalMin);

                  return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                    stream: sessionsQuery.snapshots(),
                    builder: (context, sessSnap) {
                      if (sessSnap.hasError) {
                        return _ModernError(
                          title: 'Sessions load failed',
                          error: sessSnap.error,
                          hint:
                              'If you see PERMISSION_DENIED: fix Firestore rules.\n'
                              'If you see FAILED_PRECONDITION: usually a composite index; we removed orderBy here, so it should not require one.',
                        );
                      }

                      final docs = sessSnap.data?.docs ?? [];

                      // Sort client-side so newest shows first (without needing index)
                      final sessions = [...docs]..sort((a, b) {
                          final am = a.data();
                          final bm = b.data();
                          final at = (am['startedAt'] as Timestamp?)?.millisecondsSinceEpoch ?? 0;
                          final bt = (bm['startedAt'] as Timestamp?)?.millisecondsSinceEpoch ?? 0;
                          return bt.compareTo(at);
                        });

                      return CustomScrollView(
                        slivers: [
                          SliverToBoxAdapter(
                            child: Padding(
                              padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _TopBadgesRow(streak: streak, score: score),
                                  const SizedBox(height: 14),

                                  // Two cards like your light screenshot (Today + Streak)
                                  Row(
                                    children: [
                                      Expanded(
                                        child: _SmallCard(
                                          title: 'Today',
                                          big: '$totalMin / $goalMinutes min',
                                          bottom: LinearProgressIndicator(
                                            value: progress,
                                            minHeight: 6,
                                            backgroundColor: Colors.white10,
                                            color: _accent,
                                            borderRadius: BorderRadius.circular(999),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: _SmallCard(
                                          title: 'Streak',
                                          big: '🔥  $streak days',
                                          bottom: Text(
                                            'Score: $score',
                                            style: const TextStyle(color: Colors.white60, fontWeight: FontWeight.w600),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),

                                  const SizedBox(height: 14),

                                  // ✅ Start button (you said it’s missing)
                                  _PrimaryStartButton(
                                    label: 'Start Focus',
                                    onTap: () => _startFlow(context),
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

                          if (!sessSnap.hasData)
                            const SliverFillRemaining(child: _ModernLoading(text: 'Loading sessions...'))
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
                                final d = sessions[i];
                                final m = d.data();
                                final id = d.id;

                                final intent = (m['intent'] ?? '') as String;
                                final status = (m['status'] ?? '') as String;
                                final result = (m['result'] ?? '') as String;

                                final actualSec = ((m['actualFocusSeconds'] ?? 0) as num).toInt();
                                final mins = (actualSec / 60).floor();

                                final subtitle = [
                                  '$mins min',
                                  status,
                                  if (result.isNotEmpty) result,
                                ].join(' • ');

                                return Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 16),
                                  child: _SessionRowTile(
                                    title: intent.isEmpty ? '(No intent)' : intent,
                                    subtitle: subtitle,
                                    onTap: () => Navigator.push(
                                      context,
                                      MaterialPageRoute(builder: (_) => SessionDetailScreen(uid: uid, sessionId: id)),
                                    ),
                                  ),
                                );
                              },
                            ),

                          const SliverToBoxAdapter(child: SizedBox(height: 28)),
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

      // Optional: keep FAB for quick add (nice UX)
      floatingActionButton: FloatingActionButton(
        backgroundColor: _accent,
        onPressed: () => _startFlow(context),
        child: const Icon(Icons.add),
      ),
    );
  }
}

class _TopBadgesRow extends StatelessWidget {
  const _TopBadgesRow({required this.streak, required this.score});
  final int streak;
  final int score;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: HomeScreenStateColors.card2,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: Colors.white10),
          ),
          child: Row(
            children: [
              const Icon(Icons.local_fire_department, color: Color(0xFFFF8A65), size: 18),
              const SizedBox(width: 6),
              Text(
                '${streak}d',
                style: const TextStyle(color: Colors.white70, fontWeight: FontWeight.w800),
              ),
              const SizedBox(width: 6),
              const Text('streak', style: TextStyle(color: Colors.white60, fontWeight: FontWeight.w600)),
            ],
          ),
        ),
        const SizedBox(width: 10),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: HomeScreenStateColors.card2,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: Colors.white10),
          ),
          child: Row(
            children: [
              const Icon(Icons.auto_graph, color: Color(0xFF7CDAFF), size: 18),
              const SizedBox(width: 6),
              Text(
                'score $score',
                style: const TextStyle(color: Colors.white70, fontWeight: FontWeight.w700),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Shared colors without making everything static on State.
class HomeScreenStateColors {
  static const card2 = Color(0xFF111A2D);
}

class _SmallCard extends StatelessWidget {
  const _SmallCard({
    required this.title,
    required this.big,
    required this.bottom,
  });

  final String title;
  final String big;
  final Widget bottom;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white10),
        boxShadow: const [
          BoxShadow(
            blurRadius: 22,
            color: Colors.black38,
            offset: Offset(0, 10),
          )
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(color: Colors.white70, fontWeight: FontWeight.w800)),
          const SizedBox(height: 10),
          Text(
            big,
            style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 12),
          bottom,
        ],
      ),
    );
  }
}

class _PrimaryStartButton extends StatelessWidget {
  const _PrimaryStartButton({required this.label, required this.onTap});
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(22),
      child: Container(
        height: 56,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: const Color(0xFF0F172A),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: Colors.white10),
          boxShadow: const [
            BoxShadow(
              blurRadius: 18,
              color: Colors.black45,
              offset: Offset(0, 10),
            )
          ],
        ),
        child: const Text(
          'Start Focus',
          style: TextStyle(
            color: Color(0xFFB9B6FF),
            fontSize: 18,
            fontWeight: FontWeight.w900,
            letterSpacing: 0.2,
          ),
        ),
      ),
    );
  }
}

class _SessionRowTile extends StatelessWidget {
  const _SessionRowTile({
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 0, vertical: 2),
      title: Text(
        title,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
      ),
      subtitle: Text(
        subtitle,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(color: Colors.white60, fontWeight: FontWeight.w600),
      ),
      trailing: const Icon(Icons.chevron_right, color: Colors.white38),
      onTap: onTap,
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
