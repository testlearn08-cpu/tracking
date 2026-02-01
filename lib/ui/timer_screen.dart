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
  DateTime? pauseStartedAt;

  String _fmt(int s) {
    final x = s < 0 ? 0 : s;
    final m = (x ~/ 60).toString().padLeft(2, '0');
    final r = (x % 60).toString().padLeft(2, '0');
    return '$m:$r';
  }

  void _onPaused() => pauseStartedAt = DateTime.now();

  void _onResumed() {
    final start = pauseStartedAt;
    if (start != null) {
      pausedSeconds += DateTime.now().difference(start).inSeconds;
    }
    pauseStartedAt = null;
  }

  Future<void> _finishFocus({
    required SessionService sessionService,
    required TimerController timer,
    required ActiveTimerModel a,
  }) async {
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
        MaterialPageRoute(
          builder: (_) => FeedbackScreen(uid: widget.uid, sessionId: widget.sessionId),
        ),
      );
    }
  }

  Future<void> _endNow({
    required SessionService sessionService,
    required TimerController timer,
  }) async {
    final a = timer.active;
    if (a == null) return;

    // if currently paused, count it
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
          child: StreamBuilder<int>(
            stream: timer.remainingStream,
            builder: (context, snap) {
              final a = timer.active;
              if (a == null) {
                return const Center(
                  child: Text(
                    'No active session',
                    style: TextStyle(color: Colors.white70),
                  ),
                );
              }

              final remaining = snap.data ?? a.remainingSeconds();
              final total = a.phaseDurationSeconds <= 0 ? 1 : a.phaseDurationSeconds;
              final progress = (1.0 - (remaining / total)).clamp(0.0, 1.0);

              final isFocus = a.phase == TimerPhase.focusing;
              final phaseTitle = isFocus ? 'Focus' : 'Break';
              final subTitle = isFocus ? 'Stay locked in' : 'Breathe & reset';

              // ✅ auto-finish (same behavior as before)
              if (remaining <= 0 && a.status == TimerStatus.running && a.phase == TimerPhase.focusing) {
                WidgetsBinding.instance.addPostFrameCallback((_) async {
                  if (!mounted) return;
                  await _finishFocus(sessionService: sessionService, timer: timer, a: a);
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
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      subTitle,
                      style: const TextStyle(color: Colors.white54),
                    ),
                    const SizedBox(height: 18),

                    // Ring
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

                    // Pause total
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
                            style: TextStyle(color: Colors.white70, fontWeight: FontWeight.w700),
                          ),
                          Text(
                            _fmt(pausedSeconds),
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900),
                          ),
                        ],
                      ),
                    ),

                    const Spacer(),

                    // Buttons row
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
                              } else if (a.status == TimerStatus.paused) {
                                _onResumed();
                                await timer.resume();
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
                            onTap: () => _endNow(sessionService: sessionService, timer: timer),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 10),

                    Text(
                      'Tip: Keep the phone screen on during a session for best reliability.',
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.white38, fontSize: 12),
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
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800),
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
              style: const TextStyle(color: Colors.white70, fontWeight: FontWeight.w700, fontSize: 12),
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
        ),
        icon: Icon(icon),
        label: Text(
          text,
          style: const TextStyle(fontWeight: FontWeight.w900),
        ),
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
        ),
        icon: Icon(icon),
        label: Text(
          text,
          style: const TextStyle(fontWeight: FontWeight.w900),
        ),
      ),
    );
  }
}
