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
  // Modern colors
  static const _bgTop = Color(0xFF0B1220);
  static const _bgBottom = Color(0xFF070B14);
  static const _card = Color(0xFF0F172A);
  static const _chip = Color(0xFF111A2D);
  static const _accent = Color(0xFF6C63FF);

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
    return (_fmtYmd(startDt), end);
  }

  String _filterLabel(HistoryFilter f) {
    switch (f) {
      case HistoryFilter.today:
        return 'Today';
      case HistoryFilter.week:
        return 'Week';
      case HistoryFilter.month:
        return 'Month';
    }
  }

  @override
  Widget build(BuildContext context) {
    final db = FirebaseFirestore.instance;
    final (start, end) = _rangeForFilter();

    // ✅ IMPORTANT: This avoids the composite index error.
    // Only range filter on localDate and orderBy localDate (same field).
    // Then we sort by startedAt client-side.
    final q = db
        .collection('users')
        .doc(widget.uid)
        .collection('sessions')
        .where('localDate', isGreaterThanOrEqualTo: start)
        .where('localDate', isLessThanOrEqualTo: end)
        .orderBy('localDate', descending: true)
        .limit(250);

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text('Session History', style: TextStyle(fontWeight: FontWeight.w800)),
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
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
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
                      style: const TextStyle(color: Colors.white38, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                  stream: q.snapshots(),
                  builder: (context, snap) {
                    if (snap.hasError) {
                      return _ModernError(
                        title: 'History load failed',
                        error: snap.error,
                        hint:
                            'This screen avoids the composite index.\n'
                            'If you still see FAILED_PRECONDITION, verify your code has NO orderBy(startedAt).',
                      );
                    }
                    if (!snap.hasData) {
                      return const _ModernLoading(text: 'Loading history...');
                    }

                    final docs = snap.data!.docs;

                    if (docs.isEmpty) {
                      return Center(
                        child: Text(
                          'No sessions for ${_filterLabel(filter)}',
                          style: const TextStyle(color: Colors.white60),
                        ),
                      );
                    }

                    // ✅ client-side sort: localDate desc, startedAt desc
                    final sorted = [...docs]..sort((a, b) {
                        final ad = a.data();
                        final bd = b.data();

                        final al = (ad['localDate'] ?? '') as String;
                        final bl = (bd['localDate'] ?? '') as String;
                        final cmpDate = bl.compareTo(al);
                        if (cmpDate != 0) return cmpDate;

                        final at = (ad['startedAt'] as Timestamp?)?.millisecondsSinceEpoch ?? 0;
                        final bt = (bd['startedAt'] as Timestamp?)?.millisecondsSinceEpoch ?? 0;
                        return bt.compareTo(at);
                      });

                    return ListView.separated(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                      itemCount: sorted.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 10),
                      itemBuilder: (_, i) {
                        final doc = sorted[i];
                        final d = doc.data();

                        final id = doc.id;
                        final intent = (d['intent'] ?? '') as String;
                        final status = (d['status'] ?? '') as String;
                        final result = (d['result'] ?? '') as String;
                        final localDate = (d['localDate'] ?? '') as String;

                        final seconds = ((d['actualFocusSeconds'] ?? 0) as num).toInt();
                        final mins = (seconds / 60).floor();

                        final subtitle = [
                          localDate,
                          '$mins min',
                          status,
                          if (result.isNotEmpty) result,
                        ].join(' • ');

                        return InkWell(
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => SessionDetailScreen(uid: widget.uid, sessionId: id),
                            ),
                          ),
                          borderRadius: BorderRadius.circular(18),
                          child: Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: _card,
                              borderRadius: BorderRadius.circular(18),
                              border: Border.all(color: Colors.white10),
                              boxShadow: const [
                                BoxShadow(
                                  blurRadius: 24,
                                  color: Colors.black38,
                                  offset: Offset(0, 10),
                                )
                              ],
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        intent.isEmpty ? '(No intent)' : intent,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 16,
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                      const SizedBox(height: 6),
                                      Text(
                                        subtitle,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(color: Colors.white60, fontWeight: FontWeight.w600),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 12),
                                const Icon(Icons.chevron_right, color: Colors.white38),
                              ],
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
  const _FilterChip({required this.label, required this.selected, required this.onTap});
  final String label;
  final bool selected;
  final VoidCallback onTap;

  static const _accent = Color(0xFF6C63FF);
  static const _chip = Color(0xFF111A2D);

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? _accent : _chip,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: Colors.white10),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? Colors.white : Colors.white70,
            fontWeight: FontWeight.w800,
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
