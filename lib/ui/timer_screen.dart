import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../state/timer_controller.dart';
import '../services/session_service.dart';
import '../core/notification_service.dart';
import 'feedback_screen.dart';

class TimerScreen extends StatefulWidget {
  const TimerScreen({
    super.key,
    required this.uid,
    required this.sessionId,
    required this.startedAtEpochMs,
    required this.plannedFocusSeconds,
  });

  final String uid;
  final String sessionId;
  final int startedAtEpochMs;
  final int plannedFocusSeconds;

  @override
  State<TimerScreen> createState() => _TimerScreenState();
}

class _TimerScreenState extends State<TimerScreen> {
  int pausedSeconds = 0;
  DateTime? pauseStartedAt;

  bool notifyEnabled = true;

  @override
  void initState() {
    super.initState();

    // ✅ Ensure a notification is scheduled for the current phase when screen opens.
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      final timer = context.read<TimerController>();
      final a = timer.active;
      if (a == null) return;

      // Schedule based on remaining time for current phase
      final remaining = a.remainingSeconds();
      await _rescheduleNotificationForPhase(a: a, remaining: remaining);
    });
  }

  String _fmt(int s) {
    final x = s < 0 ? 0 : s;
    final m = (x ~/ 60).toString().padLeft(2, '0');
    final r = (x % 60).toString().padLeft(2, '0');
    return '$m:$r';
  }

  void _syncPausedFromModel(ActiveTimerModel a) {
    if (pausedSeconds < a.totalPausedSeconds) pausedSeconds = a.totalPausedSeconds;

    if (a.status == TimerStatus.paused && a.pauseStartedEpochMs != null) {
      pauseStartedAt = DateTime.fromMillisecondsSinceEpoch(a.pauseStartedEpochMs!);
    }
    if (a.status == TimerStatus.running) {
      pauseStartedAt = null;
    }
  }

  Future<void> _rescheduleNotificationForPhase({
    required ActiveTimerModel a,
    required int remaining,
  }) async {
    if (!notifyEnabled) return;

    // Cancel previous scheduled notifications to avoid duplicates
    await NotificationService.instance.cancelAll();

    final id = a.phase == TimerPhase.focusing ? 1001 : 1002;
    final title = a.phase == TimerPhase.focusing ? 'Focus complete ✅' : 'Break complete ⏳';
    final body = a.phase == TimerPhase.focusing
        ? 'Nice. Log your feedback.'
        : 'Ready for your next session?';

    await NotificationService.instance.scheduleTimerDone(
      id: id,
      fromNow: Duration(seconds: remaining < 0 ? 0 : remaining),
      title: title,
      body: body,
    );
  }

  void _onPaused() => pauseStartedAt = DateTime.now();

  void _onResumed() {
    final start = pauseStartedAt;
    if (start != null) {
      pausedSeconds += DateTime.now().difference(start).inSeconds;
    }
    pauseStartedAt = null;
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
        backgroundColor: const Color(0xFF0F172A),
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

  /// Focus finished naturally.
  Future<void> _finishFocus({
    required SessionService sessionService,
    required TimerController timer,
    required ActiveTimerModel a,
  }) async {
    // Mark completed
    await sessionService.endSession(
      uid: widget.uid,
      sessionId: widget.sessionId,
      startedAt: DateTime.fromMillisecondsSinceEpoch(widget.startedAtEpochMs),
      plannedFocusSeconds: widget.plannedFocusSeconds,
      endedNormally: true,
      totalPausedSeconds: pausedSeconds,
    );

    // If no break => stop immediately and go feedback
    if (!(a.autoBreak && a.breakSeconds > 0)) {
      // ✅ DO NOT cancel notifications here.
      // The scheduled "Focus complete" notification should fire now.
      await timer.clear();
      if (!mounted) return;

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => FeedbackScreen(uid: widget.uid, sessionId: widget.sessionId),
        ),
      );
      return;
    }

    // Start break phase
    await timer.switchToBreak();

    // Schedule break completion
    final remainingBreak = timer.active?.remainingSeconds() ?? a.breakSeconds;
    await _rescheduleNotificationForPhase(
      a: timer.active!,
      remaining: remainingBreak,
    );

    if (!mounted) return;
    setState(() {});
  }

  /// Break finished naturally => stop and go feedback.
  Future<void> _finishBreak({
    required TimerController timer,
  }) async {
    // ✅ DO NOT cancel notifications here.
    // The scheduled "Break complete" notification should fire now.
    await timer.clear();
    if (!mounted) return;

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => FeedbackScreen(uid: widget.uid, sessionId: widget.sessionId),
      ),
    );
  }

  /// End now => stop and go feedback (manual stop).
  Future<void> _endNow({
    required SessionService sessionService,
    required TimerController timer,
  }) async {
    final a = timer.active;
    if (a == null) return;

    if (a.status == TimerStatus.paused) {
      _onResumed();
    }

    await sessionService.endSession(
      uid: widget.uid,
      sessionId: widget.sessionId,
      startedAt: DateTime.fromMillisecondsSinceEpoch(widget.startedAtEpochMs),
      plannedFocusSeconds: widget.plannedFocusSeconds,
      endedNormally: false,
      totalPausedSeconds: pausedSeconds,
    );

    // ✅ Manual stop should cancel scheduled notification
    await NotificationService.instance.cancelAll();
    await timer.clear();

    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => FeedbackScreen(uid: widget.uid, sessionId: widget.sessionId),
      ),
    );
  }

  /// Cancel session (return home, no feedback)
  Future<void> _cancelSession({
    required SessionService sessionService,
    required TimerController timer,
  }) async {
    final a = timer.active;
    if (a == null) return;

    if (a.status == TimerStatus.paused) {
      _onResumed();
    }

    await sessionService.endSession(
      uid: widget.uid,
      sessionId: widget.sessionId,
      startedAt: DateTime.fromMillisecondsSinceEpoch(widget.startedAtEpochMs),
      plannedFocusSeconds: widget.plannedFocusSeconds,
      endedNormally: false,
      totalPausedSeconds: pausedSeconds,
    );

    // ✅ Cancel should cancel scheduled notifications
    await NotificationService.instance.cancelAll();
    await timer.clear();

    if (!mounted) return;
    Navigator.popUntil(context, (r) => r.isFirst);
  }

  Future<void> _toggleNotifications({
    required TimerController timer,
    required ActiveTimerModel a,
    required int remaining,
  }) async {
    setState(() => notifyEnabled = !notifyEnabled);

    if (!notifyEnabled) {
      await NotificationService.instance.cancelAll();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Notifications off')),
      );
      return;
    }

    await _rescheduleNotificationForPhase(a: a, remaining: remaining);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Notifications on')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final timer = context.read<TimerController>();
    final sessionService = context.read<SessionService>();

    return Scaffold(
      backgroundColor: const Color(0xFF070B14),
      appBar: AppBar(
        title: const Text('FocusFlow'),
        backgroundColor: const Color(0xFF0B1220),
        elevation: 0,
        actions: [
          IconButton(
            tooltip: notifyEnabled ? 'Notifications on' : 'Notifications off',
            icon: Icon(
              notifyEnabled ? Icons.notifications_active : Icons.notifications_off,
            ),
            onPressed: () {
              final a = timer.active;
              if (a == null) return;
              final remaining = a.remainingSeconds();
              _toggleNotifications(timer: timer, a: a, remaining: remaining);
            },
          ),
          IconButton(
            tooltip: 'Pause/Resume',
            icon: const Icon(Icons.pause_circle_outline),
            onPressed: () async {
              final a = timer.active;
              if (a == null) return;

              if (a.status == TimerStatus.running) {
                _onPaused();
                await timer.pause();
                // paused => don’t allow scheduled countdown
                await NotificationService.instance.cancelAll();
              } else if (a.status == TimerStatus.paused) {
                _onResumed();
                await timer.resume();

                final nowA = timer.active;
                if (nowA != null) {
                  final remaining = nowA.remainingSeconds();
                  await _rescheduleNotificationForPhase(a: nowA, remaining: remaining);
                }
              }

              if (!mounted) return;
              setState(() {});
            },
          ),
          IconButton(
            tooltip: 'Cancel session',
            icon: const Icon(Icons.close),
            onPressed: () async {
              final ok = await _confirm(
                title: 'Cancel session?',
                message: 'This will stop the timer and return home (no feedback).',
                confirmText: 'Cancel session',
              );
              if (!ok) return;
              await _cancelSession(sessionService: sessionService, timer: timer);
            },
          ),
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
          child: StreamBuilder<int>(
            stream: timer.remainingStream,
            builder: (context, snap) {
              final a = timer.active;
              if (a == null) {
                return const Center(
                  child: Text('No active session', style: TextStyle(color: Colors.white70)),
                );
              }

              _syncPausedFromModel(a);

              final remaining = snap.data ?? a.remainingSeconds();
              final total = a.phaseDurationSeconds <= 0 ? 1 : a.phaseDurationSeconds;
              final progress = (1.0 - (remaining / total)).clamp(0.0, 1.0);

              final isFocus = a.phase == TimerPhase.focusing;
              final phaseTitle = isFocus ? 'Focus' : 'Break';
              final subTitle = isFocus ? 'Stay locked in' : 'Breathe & reset';

              // ✅ Auto-finish for focus
              if (remaining <= 0 && a.status == TimerStatus.running && a.phase == TimerPhase.focusing) {
                WidgetsBinding.instance.addPostFrameCallback((_) async {
                  if (!mounted) return;
                  await _finishFocus(sessionService: sessionService, timer: timer, a: a);
                });
              }

              // ✅ Auto-finish for break
              if (remaining <= 0 && a.status == TimerStatus.running && a.phase == TimerPhase.breakTime) {
                WidgetsBinding.instance.addPostFrameCallback((_) async {
                  if (!mounted) return;
                  await _finishBreak(timer: timer);
                });
              }

              return Padding(
                padding: const EdgeInsets.fromLTRB(16, 18, 16, 16),
                child: Column(
                  children: [
                    _TopPill(
                      leftText: phaseTitle,
                      rightText: a.status == TimerStatus.running ? 'Running' : 'Paused',
                      icon: isFocus ? Icons.bolt : Icons.coffee,
                    ),
                    const SizedBox(height: 16),

                    Text(
                      a.intent.isEmpty ? '(No intent)' : a.intent,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(subTitle, style: const TextStyle(color: Colors.white54)),
                    const SizedBox(height: 18),

                    SizedBox(
                      width: 240,
                      height: 240,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          SizedBox(
                            width: 240,
                            height: 240,
                            child: CircularProgressIndicator(
                              value: progress,
                              strokeWidth: 12,
                              backgroundColor: Colors.white10,
                              valueColor: AlwaysStoppedAnimation(
                                isFocus ? const Color(0xFF4F46E5) : const Color(0xFF22C55E),
                              ),
                            ),
                          ),
                          Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                _fmt(remaining),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 52,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 1,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                isFocus ? 'remaining' : 'break remaining',
                                style: const TextStyle(color: Colors.white54),
                              ),
                            ],
                          )
                        ],
                      ),
                    ),

                    const SizedBox(height: 18),

                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0F172A),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: Colors.white10),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Paused total',
                            style: TextStyle(color: Colors.white70, fontWeight: FontWeight.w800),
                          ),
                          Text(
                            _fmt(pausedSeconds),
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900),
                          ),
                        ],
                      ),
                    ),

                    const Spacer(),

                    Row(
                      children: [
                        Expanded(
                          child: _PrimaryButton(
                            text: a.status == TimerStatus.running ? 'Pause' : 'Resume',
                            icon: a.status == TimerStatus.running ? Icons.pause : Icons.play_arrow,
                            onTap: () async {
                              if (a.status == TimerStatus.running) {
                                _onPaused();
                                await timer.pause();
                                await NotificationService.instance.cancelAll();
                              } else if (a.status == TimerStatus.paused) {
                                _onResumed();
                                await timer.resume();

                                final nowA = timer.active;
                                if (nowA != null) {
                                  final rem = nowA.remainingSeconds();
                                  await _rescheduleNotificationForPhase(a: nowA, remaining: rem);
                                }
                              }
                              if (!mounted) return;
                              setState(() {});
                            },
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _DangerButton(
                            text: 'End',
                            icon: Icons.stop_circle,
                            onTap: () async {
                              final ok = await _confirm(
                                title: 'End session?',
                                message: 'This will stop the timer and go to feedback.',
                                confirmText: 'End',
                              );
                              if (!ok) return;
                              await _endNow(sessionService: sessionService, timer: timer);
                            },
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 10),

                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () async {
                              final ok = await _confirm(
                                title: 'Cancel session?',
                                message: 'Stops timer and returns home without feedback.',
                                confirmText: 'Cancel',
                              );
                              if (!ok) return;
                              await _cancelSession(sessionService: sessionService, timer: timer);
                            },
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.white70,
                              side: const BorderSide(color: Colors.white12),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                              padding: const EdgeInsets.symmetric(vertical: 14),
                            ),
                            icon: const Icon(Icons.close),
                            label: const Text('Cancel (no feedback)', style: TextStyle(fontWeight: FontWeight.w800)),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 10),

                    const Text(
                      'Tip: Disable battery optimization for best timer reliability.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.white38, fontSize: 12),
                    ),
                    const SizedBox(height: 6),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _TopPill extends StatelessWidget {
  const _TopPill({
    required this.leftText,
    required this.rightText,
    required this.icon,
  });

  final String leftText;
  final String rightText;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white10),
      ),
      child: Row(
        children: [
          Icon(icon, color: Colors.white70, size: 18),
          const SizedBox(width: 8),
          Text(
            leftText,
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900),
          ),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.06),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: Colors.white10),
            ),
            child: Text(
              rightText,
              style: const TextStyle(color: Colors.white70, fontWeight: FontWeight.w800, fontSize: 12),
            ),
          )
        ],
      ),
    );
  }
}

class _PrimaryButton extends StatelessWidget {
  const _PrimaryButton({
    required this.text,
    required this.icon,
    required this.onTap,
  });

  final String text;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 54,
      child: ElevatedButton.icon(
        onPressed: onTap,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF4F46E5),
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          elevation: 0,
        ),
        icon: Icon(icon),
        label: Text(text, style: const TextStyle(fontWeight: FontWeight.w900)),
      ),
    );
  }
}

class _DangerButton extends StatelessWidget {
  const _DangerButton({
    required this.text,
    required this.icon,
    required this.onTap,
  });

  final String text;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 54,
      child: ElevatedButton.icon(
        onPressed: onTap,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFFDC2626),
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          elevation: 0,
        ),
        icon: Icon(icon),
        label: Text(text, style: const TextStyle(fontWeight: FontWeight.w900)),
      ),
    );
  }
}
