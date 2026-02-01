import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../state/timer_controller.dart';
import '../core/notification_service.dart';
import 'feedback_screen.dart';

class BreakScreen extends StatelessWidget {
  const BreakScreen({super.key, required this.uid});
  final String uid;

  String _fmt(int s) {
    final x = s < 0 ? 0 : s;
    final m = (x ~/ 60).toString().padLeft(2, '0');
    final r = (x % 60).toString().padLeft(2, '0');
    return '$m:$r';
  }

  Future<void> _goToFeedback({
    required BuildContext context,
    required TimerController timer,
    required String sessionId,
  }) async {
    await NotificationService.instance.cancelAll();
    await timer.clear();
    if (!context.mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => FeedbackScreen(uid: uid, sessionId: sessionId),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final timer = context.read<TimerController>();

    return Scaffold(
      backgroundColor: const Color(0xFF070B14),
      appBar: AppBar(
        title: const Text('Break'),
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
                    'No active timer',
                    style: TextStyle(color: Colors.white70),
                  ),
                );
              }

              final remaining = snap.data ?? a.remainingSeconds();
              final total = a.phaseDurationSeconds <= 0 ? 1 : a.phaseDurationSeconds;
              final progress = (1.0 - (remaining / total)).clamp(0.0, 1.0);

              // ✅ Auto-finish break → Feedback
              if (remaining <= 0 && a.status == TimerStatus.running) {
                WidgetsBinding.instance.addPostFrameCallback((_) async {
                  await _goToFeedback(
                    context: context,
                    timer: timer,
                    sessionId: a.sessionId,
                  );
                });
              }

              return Padding(
                padding: const EdgeInsets.fromLTRB(16, 18, 16, 16),
                child: Column(
                  children: [
                    const _TopPill(),
                    const SizedBox(height: 16),

                    const Text(
                      'Take a short break',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Stand up • Drink water • Relax your eyes',
                      style: TextStyle(color: Colors.white54),
                      textAlign: TextAlign.center,
                    ),
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
                              valueColor: const AlwaysStoppedAnimation(Color(0xFF22C55E)),
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
                              const Text(
                                'break remaining',
                                style: TextStyle(color: Colors.white54),
                              ),
                            ],
                          )
                        ],
                      ),
                    ),

                    const Spacer(),

                    Row(
                      children: [
                        Expanded(
                          child: _SecondaryButton(
                            text: 'Skip break',
                            icon: Icons.fast_forward,
                            onTap: () => _goToFeedback(
                              context: context,
                              timer: timer,
                              sessionId: a.sessionId,
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 10),
                    const Text(
                      'Tip: short breaks improve focus consistency.',
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
  const _TopPill();

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
          const Icon(Icons.coffee, color: Colors.white70, size: 18),
          const SizedBox(width: 8),
          const Text(
            'Break',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800),
          ),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.06),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: Colors.white10),
            ),
            child: const Text(
              'Recover',
              style: TextStyle(
                color: Colors.white70,
                fontWeight: FontWeight.w700,
                fontSize: 12,
              ),
            ),
          )
        ],
      ),
    );
  }
}

class _SecondaryButton extends StatelessWidget {
  const _SecondaryButton({
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
          backgroundColor: const Color(0xFF111A2D),
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          side: BorderSide(color: Colors.white.withOpacity(0.12)),
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
