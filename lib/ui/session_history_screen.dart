import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'session_detail_screen.dart';

enum HistoryFilter { today, week, month }

class SessionHistoryScreen extends StatefulWidget {
  const SessionHistoryScreen({super.key, required this.uid});
  final String uid;

  @override
  State<SessionHistoryScreen> createState() => _SessionHistoryScreenState();
}

class _SessionHistoryScreenState extends State<SessionHistoryScreen> {
  HistoryFilter filter = HistoryFilter.today;

  String _fmtYmd(DateTime dt) {
    final y = dt.year.toString().padLeft(4, '0');
    final m = dt.month.toString().padLeft(2, '0');
    final d = dt.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }

  (String start, String end) _rangeForFilter() {
    final nowUtc = DateTime.now().toUtc();
    final ist = nowUtc.add(const Duration(hours: 5, minutes: 30));
    final end = _fmtYmd(ist);

    DateTime startDt;
    switch (filter) {
      case HistoryFilter.today:
        startDt = ist;
        break;
      case HistoryFilter.week:
        startDt = ist.subtract(const Duration(days: 6));
        break;
      case HistoryFilter.month:
        startDt = ist.subtract(const Duration(days: 29));
        break;
    }
    final start = _fmtYmd(startDt);
    return (start, end);
  }

  @override
  Widget build(BuildContext context) {
    final db = FirebaseFirestore.instance;
    final (start, end) = _rangeForFilter();

    final q = db
        .collection('users')
        .doc(widget.uid)
        .collection('sessions')
        .where('localDate', isGreaterThanOrEqualTo: start)
        .where('localDate', isLessThanOrEqualTo: end)
        .orderBy('localDate', descending: true)
        .orderBy('startedAt', descending: true)
        .limit(200);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Session History'),
        actions: [
          PopupMenuButton<HistoryFilter>(
            onSelected: (v) => setState(() => filter = v),
            itemBuilder: (_) => const [
              PopupMenuItem(value: HistoryFilter.today, child: Text('Today')),
              PopupMenuItem(value: HistoryFilter.week, child: Text('Week')),
              PopupMenuItem(value: HistoryFilter.month, child: Text('Month')),
            ],
          )
        ],
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: q.snapshots(),
        builder: (context, snap) {
          if (!snap.hasData) return const Center(child: CircularProgressIndicator());
          final docs = snap.data!.docs;
          if (docs.isEmpty) return const Center(child: Text('No sessions found'));

          return ListView.separated(
            itemCount: docs.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (_, i) {
              final d = docs[i].data();
              final id = docs[i].id;

              final intent = (d['intent'] ?? '') as String;
              final status = (d['status'] ?? '') as String;
              final result = (d['result'] ?? '') as String;
              final localDate = (d['localDate'] ?? '') as String;

              final seconds = ((d['actualFocusSeconds'] ?? 0) as num).toInt();
              final mins = (seconds / 60).floor();

              return ListTile(
                title: Text(intent.isEmpty ? '(No intent)' : intent, maxLines: 1, overflow: TextOverflow.ellipsis),
                subtitle: Text('$localDate • $mins min • $status ${result.isNotEmpty ? "• $result" : ""}'),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => SessionDetailScreen(uid: widget.uid, sessionId: id)),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
