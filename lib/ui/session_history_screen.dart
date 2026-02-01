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
    // IST range based on current time
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
          child: Column(
            children: [
              // Filter row (modern chips)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                child: Row(
                  children: [
                    _FilterChip(
                      label: 'Today',
                      selected: filter == HistoryFilter.today,
                      onTap: () => setState(() => filter = HistoryFilter.today),
                    ),
                    const SizedBox(width: 10),
                    _FilterChip(
                      label: 'Week',
                      selected: filter == HistoryFilter.week,
                      onTap: () => setState(() => filter = HistoryFilter.week),
                    ),
                    const SizedBox(width: 10),
                    _FilterChip(
                      label: 'Month',
                      selected: filter == HistoryFilter.month,
                      onTap: () => setState(() => filter = HistoryFilter.month),
                    ),
                    const Spacer(),
                    Text(
                      '$start → $end',
                      style: const TextStyle(color: Colors.white38, fontSize: 12),
                    ),
                  ],
                ),
              ),

              Expanded(
                child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                  // Key forces StreamBuilder to fully rewire when filter changes
                  key: ValueKey('${filter.name}-$start-$end'),
                  stream: q.snapshots(),
                  builder: (context, snap) {
                    // ✅ IMPORTANT: show errors (fixes "infinite loading")
                    if (snap.hasError) {
                      return _ModernError(
                        title: 'History load failed',
                        error: snap.error,
                        hint:
                            'Most common causes:\n'
                            '• Missing Firestore composite index (FAILED_PRECONDITION)\n'
                            '• Firestore rules (PERMISSION_DENIED)\n\n'
                            'For this query, you likely need a composite index on:\n'
                            'localDate (desc) + startedAt (desc)\n\n'
                            'Open your console error link and click Create.',
                      );
                    }

                    if (snap.connectionState == ConnectionState.waiting && !snap.hasData) {
                      return const _ModernLoading(text: 'Loading history...');
                    }

                    final docs = snap.data?.docs ?? [];
                    if (docs.isEmpty) {
                      return const Center(
                        child: Text(
                          'No sessions found',
                          style: TextStyle(color: Colors.white60),
                        ),
                      );
                    }

                    return ListView.separated(
                      padding: const EdgeInsets.fromLTRB(16, 6, 16, 16),
                      itemCount: docs.length,
                      separatorBuilder: (_, __) => const Divider(color: Colors.white10, height: 1),
                      itemBuilder: (_, i) {
                        final doc = docs[i];
                        final d = doc.data();
                        final id = doc.id;

                        final intent = (d['intent'] ?? '') as String;
                        final status = (d['status'] ?? '') as String;
                        final result = (d['result'] ?? '') as String;
                        final localDate = (d['localDate'] ?? '') as String;

                        final seconds = ((d['actualFocusSeconds'] ?? 0) as num).toInt();
                        final mins = (seconds / 60).floor();

                        final subtitleParts = <String>[
                          localDate,
                          '$mins min',
                          status,
                          if (result.isNotEmpty) result,
                        ];

                        return ListTile(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 0, vertical: 6),
                          title: Text(
                            intent.isEmpty ? '(No intent)' : intent,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
                          ),
                          subtitle: Text(
                            subtitleParts.join(' • '),
                            style: const TextStyle(color: Colors.white60),
                          ),
                          trailing: const Icon(Icons.chevron_right, color: Colors.white38),
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => SessionDetailScreen(uid: widget.uid, sessionId: id),
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFF4F46E5) : const Color(0xFF0F172A),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: Colors.white10),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? Colors.white : Colors.white70,
            fontWeight: FontWeight.w700,
            fontSize: 12,
          ),
        ),
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
            const SizedBox(
              width: 34,
              height: 34,
              child: CircularProgressIndicator(strokeWidth: 3),
            ),
            const SizedBox(height: 12),
            Text(text, style: const TextStyle(color: Colors.white60)),
          ],
        ),
      ),
    );
  }
}

class _ModernError extends StatelessWidget {
  const _ModernError({
    required this.title,
    required this.error,
    required this.hint,
  });

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
                Text(
                  title,
                  style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 10),
                Text(
                  '$error',
                  style: const TextStyle(color: Colors.white70, fontFamily: 'monospace'),
                ),
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
