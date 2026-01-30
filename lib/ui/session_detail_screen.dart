import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class SessionDetailScreen extends StatelessWidget {
  const SessionDetailScreen({super.key, required this.uid, required this.sessionId});

  final String uid;
  final String sessionId;

  String _fmtTs(Timestamp? ts) {
    if (ts == null) return '-';
    final dt = ts.toDate();
    final hh = dt.hour.toString().padLeft(2, '0');
    final mm = dt.minute.toString().padLeft(2, '0');
    return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}  $hh:$mm';
  }

  @override
  Widget build(BuildContext context) {
    final ref = FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('sessions')
        .doc(sessionId);

    return Scaffold(
      appBar: AppBar(title: const Text('Session Details')),
      body: FutureBuilder(
        future: ref.get(),
        builder: (context, snap) {
          if (!snap.hasData) return const Center(child: CircularProgressIndicator());
          final doc = snap.data!;
          if (!doc.exists) return const Center(child: Text('Session not found'));

          final d = doc.data() as Map<String, dynamic>;

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

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text(intent.isEmpty ? '(No intent)' : intent, style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 8),
              Text('Date: $localDate'),
              Text('Status: $status ${result.isNotEmpty ? "• $result" : ""}'),
              const Divider(height: 24),

              _kv('Started', _fmtTs(startedAt)),
              _kv('Ended', _fmtTs(endedAt)),
              _kv('Preset', '$presetMinutes min'),
              _kv('Break', '$breakMinutes min'),
              _kv('Actual focus', '${(actualSec / 60).floor()} min'),
              _kv('Overtime', '${(overtimeSec / 60).floor()} min'),
              _kv('Distraction', distraction?.toString() ?? '-'),
              _kv('Distractors', distractors.isEmpty ? '-' : distractors.join(', ')),
              const SizedBox(height: 12),
              Text('Notes', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 6),
              Text(notes.isEmpty ? '-' : notes),
            ],
          );
        },
      ),
    );
  }

  Widget _kv(String k, String v) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 120, child: Text(k, style: const TextStyle(fontWeight: FontWeight.w600))),
          Expanded(child: Text(v)),
        ],
      ),
    );
  }
}
