import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';

import '../state/timer_controller.dart';
import '../services/session_service.dart';
import '../core/notification_service.dart';
import 'timer_screen.dart';
import 'feedback_screen.dart';

class SessionDetailScreen extends StatefulWidget {
  const SessionDetailScreen({super.key, required this.uid, required this.sessionId});

  final String uid;
  final String sessionId;

  @override
  State<SessionDetailScreen> createState() => _SessionDetailScreenState();
}

class _SessionDetailScreenState extends State<SessionDetailScreen> {
  static const _bgTop = Color(0xFF0B1220);
  static const _bgBottom = Color(0xFF070B14);
  static const _card = Color(0xFF0F172A);

  bool notifyEnabled = true;

  String _fmtTs(Timestamp? ts) {
    if (ts == null) return '-';
    final dt = ts.toDate();
    final hh = dt.hour.toString().padLeft(2, '0');
    final mm = dt.minute.toString().padLeft(2, '0');
    return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}  $hh:$mm';
  }

  String _fmt(int s) {
    final x = s < 0 ? 0 : s;
    final m = (x ~/ 60).toString().padLeft(2, '0');
    final r = (x % 60).toString().padLeft(2, '0');
    return '$m:$r';
  }

  Future<bool> _confirm({
    required String title,
    required String message,
    required String confirmText,
    Color confirmColor = const Color(0xFFDC2626),
  }) async {
    final res = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: _card,
        title: Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900)),
        content: Text(message, style: const TextStyle(color: Colors.white70)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('No', style: TextStyle(color: Colors.white70)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: confirmColor,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: Text(confirmText, style: const TextStyle(fontWeight: FontWeight.w900)),
          ),
        ],
      ),
    );
    return res == true;
  }

  Future<void> _toggleNotifications(ActiveTimerModel a) async {
    setState(() => notifyEnabled = !notifyEnabled);

    if (!notifyEnabled) {
      await NotificationService.instance.cancelAll();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Notifications off')));
      return;
    }

    final remaining = a.remainingSeconds();
    final id = a.phase == TimerPhase.focusing ? 1001 : 1002;
    final title = a.phase == TimerPhase.focusing ? 'Focus complete ✅' : 'Break complete ⏳';
    final body = a.phase == TimerPhase.focusing ? 'Nice. Log your feedback.' : 'Ready for your next session?';

    await NotificationService.instance.cancelAll();
    await NotificationService.instance.scheduleTimerDone(
      id: id,
      fromNow: Duration(seconds: remaining < 0 ? 0 : remaining),
      title: title,
      body: body,
    );

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Notifications on')));
  }

  @override
  Widget build(BuildContext context) {
    final ref = FirebaseFirestore.instance
        .collection('users')
        .doc(widget.uid)
        .collection('sessions')
        .doc(widget.sessionId);

    final timer = context.read<TimerController>();

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text('Session Details', style: TextStyle(fontWeight: FontWeight.w900)),
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
          child: FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
            future: ref.get(),
            builder: (context, snap) {
              if (snap.hasError) {
                return _ModernError(
                  title: 'Failed to load session',
                  error: snap.error,
                  hint: 'Check Firestore rules and connectivity.',
                );
              }
              if (!snap.hasData) {
                return const _ModernLoading(text: 'Loading session...');
              }

              final doc = snap.data!;
              if (!doc.exists) {
                return const Center(
                  child: Text('Session not found', style: TextStyle(color: Colors.white60)),
                );
              }

              final d = doc.data() ?? {};

              final intent = (d['intent'] ?? '') as String;
              final localDate = (d['localDate'] ?? '') as String;
              final status = (d['status'] ?? '') as String;
              final result = (d['result'] ?? '') as String;

              final presetMinutes = ((d['presetMinutes'] ?? 0) as num).toInt();
              final breakMinutes = ((d['breakMinutes'] ?? 0) as num).toInt();
              final actualSec = ((d['actualFocusSeconds'] ?? 0) as num).toInt();
              final overtimeSec = ((d['overtimeSeconds'] ?? 0) as num).toInt();

              final distraction = (d['distractionLevel'] as num?)?.toInt();
              final distractors = (d['distractors'] as List?)?.cast<String>() ?? [];
              final notes = (d['notes'] ?? '') as String;

              final startedAt = d['startedAt'] as Timestamp?;
              final endedAt = d['endedAt'] as Timestamp?;

              final startedAtEpochMs = startedAt?.toDate().millisecondsSinceEpoch ?? DateTime.now().millisecondsSinceEpoch;
              final plannedFocusSeconds = (presetMinutes <= 0 ? 0 : presetMinutes * 60);

              final a = timer.active;
              final isLive = a != null && a.sessionId == widget.sessionId && a.uid == widget.uid;

              String statusLine = status;
              if (result.isNotEmpty) statusLine = '$status • $result';

              return ListView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
                children: [
                  // Header card
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: _card,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: Colors.white10),
                      boxShadow: const [BoxShadow(blurRadius: 26, color: Colors.black38, offset: Offset(0, 10))],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          intent.isEmpty ? '(No intent)' : intent,
                          style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w900),
                        ),
                        const SizedBox(height: 8),
                        Text('Date: $localDate', style: const TextStyle(color: Colors.white70, fontWeight: FontWeight.w700)),
                        Text('Status: $statusLine', style: const TextStyle(color: Colors.white70, fontWeight: FontWeight.w700)),
                      ],
                    ),
                  ),

                  // ✅ LIVE TIMER CARD (only if active)
                  if (isLive) ...[
                    const SizedBox(height: 12),
                    _LiveTimerCard(
                      notifyEnabled: notifyEnabled,
                      onToggleBell: () => _toggleNotifications(a!),
                      onOpenFull: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => TimerScreen(
                              uid: widget.uid,
                              sessionId: widget.sessionId,
                              startedAtEpochMs: startedAtEpochMs,
                              plannedFocusSeconds: plannedFocusSeconds,
                            ),
                          ),
                        );
                      },
                      onPauseResume: () async {
                        final nowA = timer.active;
                        if (nowA == null) return;

                        if (nowA.status == TimerStatus.running) {
                          await timer.pause();
                          await NotificationService.instance.cancelAll();
                        } else {
                          await timer.resume();
                          if (notifyEnabled) {
                            final rem = timer.active?.remainingSeconds() ?? 0;
                            final id = nowA.phase == TimerPhase.focusing ? 1001 : 1002;
                            final title = nowA.phase == TimerPhase.focusing ? 'Focus complete ✅' : 'Break complete ⏳';
                            final body =
                                nowA.phase == TimerPhase.focusing ? 'Nice. Log your feedback.' : 'Ready for your next session?';
                            await NotificationService.instance.cancelAll();
                            await NotificationService.instance.scheduleTimerDone(
                              id: id,
                              fromNow: Duration(seconds: rem < 0 ? 0 : rem),
                              title: title,
                              body: body,
                            );
                          }
                        }
                        if (!mounted) return;
                        setState(() {});
                      },
                      onEnd: () async {
                        final ok = await _confirm(
                          title: 'End session?',
                          message: 'Stops the timer and opens feedback.',
                          confirmText: 'End',
                        );
                        if (!ok) return;

                        final service = context.read<SessionService>();
                        final nowA = timer.active;
                        if (nowA == null) return;

                        await service.endSession(
                          uid: widget.uid,
                          sessionId: widget.sessionId,
                          startedAt: DateTime.fromMillisecondsSinceEpoch(startedAtEpochMs),
                          plannedFocusSeconds: plannedFocusSeconds,
                          endedNormally: false,
                          totalPausedSeconds: nowA.totalPausedSeconds,
                        );

                        await NotificationService.instance.cancelAll();
                        await timer.clear();

                        if (!mounted) return;
                        Navigator.pushReplacement(
                          context,
                          MaterialPageRoute(builder: (_) => FeedbackScreen(uid: widget.uid, sessionId: widget.sessionId)),
                        );
                      },
                      onCancel: () async {
                        final ok = await _confirm(
                          title: 'Cancel session?',
                          message: 'Stops the timer and returns home (no feedback).',
                          confirmText: 'Cancel',
                        );
                        if (!ok) return;

                        final service = context.read<SessionService>();
                        final nowA = timer.active;
                        if (nowA == null) return;

                        await service.endSession(
                          uid: widget.uid,
                          sessionId: widget.sessionId,
                          startedAt: DateTime.fromMillisecondsSinceEpoch(startedAtEpochMs),
                          plannedFocusSeconds: plannedFocusSeconds,
                          endedNormally: false,// change to true if want to include the session closed directly
                          totalPausedSeconds: nowA.totalPausedSeconds,
                        );

                        await NotificationService.instance.cancelAll();
                        await timer.clear();

                        if (!mounted) return;
                        Navigator.popUntil(context, (r) => r.isFirst);
                      },
                    ),
                  ],

                  const SizedBox(height: 14),

                  _SectionCard(
                    title: 'Timing',
                    children: [
                      _kv('Started', _fmtTs(startedAt)),
                      _kv('Ended', _fmtTs(endedAt)),
                      _kv('Preset', '$presetMinutes min'),
                      _kv('Break', '$breakMinutes min'),
                    ],
                  ),
                  const SizedBox(height: 12),

                  _SectionCard(
                    title: 'Results',
                    children: [
                      _kv('Actual focus', '${(actualSec / 60).floor()} min'),
                      _kv('Overtime', '${(overtimeSec / 60).floor()} min'),
                      _kv('Distraction', distraction?.toString() ?? '-'),
                      _kv('Distractors', distractors.isEmpty ? '-' : distractors.join(', ')),
                    ],
                  ),
                  const SizedBox(height: 12),

                  _SectionCard(
                    title: 'Notes',
                    children: [
                      Text(
                        notes.isEmpty ? '-' : notes,
                        style: const TextStyle(color: Colors.white70, fontWeight: FontWeight.w700),
                      ),
                    ],
                  ),

                  const SizedBox(height: 6),
                  if (!isLive)
                    const Text(
                      'Tip: Open this session while it is running to see the live timer here.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.white38, fontSize: 12),
                    ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _kv(String k, String v) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(k, style: const TextStyle(color: Colors.white60, fontWeight: FontWeight.w900)),
          ),
          Expanded(
            child: Text(v, style: const TextStyle(color: Colors.white70, fontWeight: FontWeight.w800)),
          ),
        ],
      ),
    );
  }
}

class _LiveTimerCard extends StatelessWidget {
  const _LiveTimerCard({
    required this.notifyEnabled,
    required this.onToggleBell,
    required this.onPauseResume,
    required this.onOpenFull,
    required this.onEnd,
    required this.onCancel,
  });

  final bool notifyEnabled;
  final VoidCallback onToggleBell;
  final VoidCallback onPauseResume;
  final VoidCallback onOpenFull;
  final VoidCallback onEnd;
  final VoidCallback onCancel;

  static const _card = Color(0xFF0F172A);

  String _fmt(int s) {
    final x = s < 0 ? 0 : s;
    final m = (x ~/ 60).toString().padLeft(2, '0');
    final r = (x % 60).toString().padLeft(2, '0');
    return '$m:$r';
  }

  @override
  Widget build(BuildContext context) {
    final timer = context.read<TimerController>();

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white10),
      ),
      child: StreamBuilder<int>(
        stream: timer.remainingStream,
        builder: (context, snap) {
          final a = timer.active;
          if (a == null) {
            return const Text('No active timer', style: TextStyle(color: Colors.white70));
          }

          final remaining = snap.data ?? a.remainingSeconds();
          final isFocus = a.phase == TimerPhase.focusing;
          final phase = isFocus ? 'FOCUS' : 'BREAK';
          final status = a.status == TimerStatus.running ? 'RUNNING' : 'PAUSED';

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.06),
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(color: Colors.white10),
                    ),
                    child: Text(phase, style: const TextStyle(color: Colors.white70, fontWeight: FontWeight.w900, fontSize: 12)),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.06),
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(color: Colors.white10),
                    ),
                    child: Text(status, style: const TextStyle(color: Colors.white70, fontWeight: FontWeight.w900, fontSize: 12)),
                  ),
                  const Spacer(),
                  IconButton(
                    onPressed: onToggleBell,
                    icon: Icon(
                      notifyEnabled ? Icons.notifications_active : Icons.notifications_off,
                      color: Colors.white70,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),

              Text(
                _fmt(remaining),
                style: const TextStyle(color: Colors.white, fontSize: 44, fontWeight: FontWeight.w900, letterSpacing: 1),
              ),
              const SizedBox(height: 10),

              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: onPauseResume,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF4F46E5),
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      icon: Icon(a.status == TimerStatus.running ? Icons.pause : Icons.play_arrow),
                      label: Text(
                        a.status == TimerStatus.running ? 'Pause' : 'Resume',
                        style: const TextStyle(fontWeight: FontWeight.w900),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: onOpenFull,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white70,
                        side: const BorderSide(color: Colors.white12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      icon: const Icon(Icons.open_in_full),
                      label: const Text('Open', style: TextStyle(fontWeight: FontWeight.w900)),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: onEnd,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFDC2626),
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      icon: const Icon(Icons.stop_circle),
                      label: const Text('End', style: TextStyle(fontWeight: FontWeight.w900)),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: onCancel,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white70,
                        side: const BorderSide(color: Colors.white12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      icon: const Icon(Icons.close),
                      label: const Text('Cancel', style: TextStyle(fontWeight: FontWeight.w900)),
                    ),
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  static const _card = Color(0xFF0F172A);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w900)),
          const SizedBox(height: 12),
          ...children,
        ],
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
  const _ModernError({required this.title, required this.error, required this.hint});

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
