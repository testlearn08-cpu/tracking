import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../state/timer_controller.dart';
import '../core/notification_service.dart';
import 'feedback_screen.dart';

class BreakScreen extends StatelessWidget {
  const BreakScreen({super.key, required this.uid});
  final String uid;

  String _fmt(int s) {
    final m = (s ~/ 60).toString().padLeft(2, '0');
    final r = (s % 60).toString().padLeft(2, '0');
    return '$m:$r';
  }

  @override
  Widget build(BuildContext context) {
    final timer = context.read<TimerController>();

    return Scaffold(
      appBar: AppBar(title: const Text('Break')),
      body: StreamBuilder<int>(
        stream: timer.remainingStream,
        builder: (context, snap) {
          final a = timer.active;
          if (a == null) return const Center(child: Text('No active timer'));

          final remaining = snap.data ?? a.remainingSeconds();

          if (remaining <= 0 && a.status == TimerStatus.running) {
            WidgetsBinding.instance.addPostFrameCallback((_) async {
              await NotificationService.instance.cancelAll();
              await timer.clear();
              if (!context.mounted) return;
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (_) => FeedbackScreen(uid: uid, sessionId: a.sessionId)),
              );
            });
          }

          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text('Take a short break'),
                const SizedBox(height: 16),
                Text(_fmt(remaining < 0 ? 0 : remaining),
                    style: const TextStyle(fontSize: 48, fontWeight: FontWeight.bold)),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () async {
                    await NotificationService.instance.cancelAll();
                    await timer.clear();
                    if (!context.mounted) return;
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(builder: (_) => FeedbackScreen(uid: uid, sessionId: a.sessionId)),
                    );
                  },
                  child: const Text('Skip Break'),
                )
              ],
            ),
          );
        },
      ),
    );
  }
}
