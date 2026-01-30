import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/session_service.dart';

class FeedbackScreen extends StatefulWidget {
  const FeedbackScreen({super.key, required this.uid, required this.sessionId});
  final String uid;
  final String sessionId;

  @override
  State<FeedbackScreen> createState() => _FeedbackScreenState();
}

class _FeedbackScreenState extends State<FeedbackScreen> {
  String result = 'done';
  double distraction = 2;
  final notesCtrl = TextEditingController();

  @override
  void dispose() {
    notesCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final service = context.read<SessionService>();

    return Scaffold(
      appBar: AppBar(title: const Text('Session Feedback')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            const Text('Did you finish what you planned?'),
            RadioListTile(
              value: 'done',
              groupValue: result,
              onChanged: (v) => setState(() => result = v!),
              title: const Text('Done'),
            ),
            RadioListTile(
              value: 'partial',
              groupValue: result,
              onChanged: (v) => setState(() => result = v!),
              title: const Text('Partially'),
            ),
            RadioListTile(
              value: 'not_done',
              groupValue: result,
              onChanged: (v) => setState(() => result = v!),
              title: const Text('Not done'),
            ),
            const SizedBox(height: 12),
            Text('Distraction level: ${distraction.round()}'),
            Slider(
              value: distraction,
              min: 1,
              max: 5,
              divisions: 4,
              onChanged: (v) => setState(() => distraction = v),
            ),
            TextField(
              controller: notesCtrl,
              decoration: const InputDecoration(labelText: 'Notes (optional)'),
            ),
            const Spacer(),
            ElevatedButton(
              onPressed: () async {
                await service.submitFeedbackAndUpdateStats(
                  uid: widget.uid,
                  sessionId: widget.sessionId,
                  result: result,
                  distractionLevel: distraction.round(),
                  notes: notesCtrl.text.trim(),
                );
                if (!mounted) return;
                Navigator.popUntil(context, (r) => r.isFirst);
              },
              child: const Text('Save'),
            )
          ],
        ),
      ),
    );
  }
}
