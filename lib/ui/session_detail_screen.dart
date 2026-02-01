import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class SessionDetailScreen extends StatelessWidget {
  const SessionDetailScreen({super.key, required this.uid, required this.sessionId});

  final String uid;
  final String sessionId;

  static const _bgTop = Color(0xFF0B1220);
  static const _bgBottom = Color(0xFF070B14);
  static const _card = Color(0xFF0F172A);

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
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text('Session Details', style: TextStyle(fontWeight: FontWeight.w800)),
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

              String statusLine = status;
              if (result.isNotEmpty) statusLine = '$status • $result';

              return ListView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: _card,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: Colors.white10),
                      boxShadow: const [
                        BoxShadow(blurRadius: 26, color: Colors.black38, offset: Offset(0, 10)),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          intent.isEmpty ? '(No intent)' : intent,
                          style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w900),
                        ),
                        const SizedBox(height: 8),
                        Text('Date: $localDate', style: const TextStyle(color: Colors.white70, fontWeight: FontWeight.w600)),
                        Text('Status: $statusLine',
                            style: const TextStyle(color: Colors.white70, fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ),
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
                        style: const TextStyle(color: Colors.white70, fontWeight: FontWeight.w600),
                      ),
                    ],
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
            child: Text(k, style: const TextStyle(color: Colors.white60, fontWeight: FontWeight.w800)),
          ),
          Expanded(
            child: Text(v, style: const TextStyle(color: Colors.white70, fontWeight: FontWeight.w700)),
          ),
        ],
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
