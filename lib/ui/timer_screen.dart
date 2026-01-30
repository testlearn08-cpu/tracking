import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../state/timer_controller.dart';
import '../services/session_service.dart';
import '../core/notification_service.dart';
import 'break_screen.dart';
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

  String _fmt(int s) {
    final m = (s ~/ 60).toString().padLeft(2, '0');
    final r = (s % 60).toString().padLeft(2, '0');
    return '$m:$r';
  }

  @override
  Widget build(BuildContext context) {
    final timer = context.read<TimerController>();
    final sessionService = context.read<SessionService>();

    return Scaffold(
      appBar: AppBar(title: const Text('Focus')),
      body: StreamBuilder<int>(
        stream: timer.remainingStream,
        builder: (context, snap) {
          final a = timer.active;
          if (a == null) return const Center(child: Text('No active session'));

          final remaining = snap.data ?? a.remainingSeconds();

          if (remaining <= 0 && a.status == TimerStatus.running) {
            WidgetsBinding.instance.addPostFrameCallback((_) async {
              if (!mounted) return;

              if (a.phase == TimerPhase.focusing) {
                await sessionService.endSession(
                  uid: widget.uid,
                  sessionId: widget.sessionId,
                  startedAt: DateTime.fromMillisecondsSinceEpoch(widget.startedAtEpochMs),
                  plannedFocusSeconds: widget.plannedFocusSeconds,
                  endedNormally: true,
                  totalPausedSeconds: pausedSeconds,
                );

                if (a.autoBreak && a.breakSeconds > 0) {
                  await timer.switchToBreak();

                  await NotificationService.instance.cancelAll();
                  await NotificationService.instance.scheduleTimerDone(
                    id: 1002,
                    fromNow: Duration(seconds: a.breakSeconds),
                    title: 'Break complete ⏳',
                    body: 'Ready for your next session?',
                  );

                  if (!mounted) return;
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(builder: (_) => BreakScreen(uid: widget.uid)),
                  );
                } else {
                  await NotificationService.instance.cancelAll();
                  await timer.clear();
                  if (!mounted) return;
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(builder: (_) => FeedbackScreen(uid: widget.uid, sessionId: widget.sessionId)),
                  );
                }
              }
            });
          }

          return Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Text(a.intent, style: const TextStyle(fontSize: 18)),
                const SizedBox(height: 24),
                Text(_fmt(remaining < 0 ? 0 : remaining),
                    style: const TextStyle(fontSize: 56, fontWeight: FontWeight.bold)),
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    ElevatedButton(
                      onPressed: () async {
                        if (a.status == TimerStatus.running) {
                          await timer.pause();
                        } else if (a.status == TimerStatus.paused) {
                          await timer.resume();
                        }
                        setState(() {});
                      },
                      child: Text(a.status == TimerStatus.running ? 'Pause' : 'Resume'),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton(
                      onPressed: () async {
                        await sessionService.endSession(
                          uid: widget.uid,
                          sessionId: widget.sessionId,
                          startedAt: DateTime.fromMillisecondsSinceEpoch(widget.startedAtEpochMs),
                          plannedFocusSeconds: widget.plannedFocusSeconds,
                          endedNormally: false,
                          totalPausedSeconds: pausedSeconds,
                        );
                        await NotificationService.instance.cancelAll();
                        await timer.clear();
                        if (!mounted) return;
                        Navigator.pushReplacement(
                          context,
                          MaterialPageRoute(builder: (_) => FeedbackScreen(uid: widget.uid, sessionId: widget.sessionId)),
                        );
                      },
                      child: const Text('End'),
                    ),
                  ],
                )
              ],
            ),
          );
        },
      ),
    );
  }
}
