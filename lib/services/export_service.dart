import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:csv/csv.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:pdf/widgets.dart' as pw;

class ExportService {
  ExportService(this.db);
  final FirebaseFirestore db;

  Future<List<Map<String, dynamic>>> fetchDailyStatsRange({
    required String uid,
    required String startYmd,
    required String endYmd,
  }) async {
    final col = db.collection('users').doc(uid).collection('dailyStats');
    final q = await col
        .where('date', isGreaterThanOrEqualTo: startYmd)
        .where('date', isLessThanOrEqualTo: endYmd)
        .orderBy('date', descending: false)
        .get();
    return q.docs.map((d) => d.data()).toList();
  }

  Future<File> exportCsv({
    required String uid,
    required String startYmd,
    required String endYmd,
  }) async {
    final rows = await fetchDailyStatsRange(uid: uid, startYmd: startYmd, endYmd: endYmd);

    final data = <List<dynamic>>[
      ['date', 'totalFocusMinutes', 'sessionsCount', 'focusScore', 'goalMet'],
      ...rows.map((r) {
        final date = r['date'] ?? '';
        final totalSec = ((r['totalFocusSeconds'] ?? 0) as num).toInt();
        final mins = (totalSec / 60).floor();
        final sessions = ((r['sessionsCount'] ?? 0) as num).toInt();
        final score = ((r['focusScore'] ?? 0) as num).toInt();
        final goalMet = (r['goalMet'] == true) ? 'true' : 'false';
        return [date, mins, sessions, score, goalMet];
      })
    ];

    final csvStr = const ListToCsvConverter().convert(data);

    final dir = await getApplicationDocumentsDirectory();
    final file = File('${dir.path}/focusflow_$startYmd-to-$endYmd.csv');
    await file.writeAsString(csvStr);
    return file;
  }

  Future<File> exportPdf({
    required String uid,
    required String startYmd,
    required String endYmd,
  }) async {
    final rows = await fetchDailyStatsRange(uid: uid, startYmd: startYmd, endYmd: endYmd);

    int totalMinutes = 0;
    int totalSessions = 0;
    int daysMet = 0;

    for (final r in rows) {
      totalMinutes += (((r['totalFocusSeconds'] ?? 0) as num).toInt() / 60).floor();
      totalSessions += ((r['sessionsCount'] ?? 0) as num).toInt();
      if (r['goalMet'] == true) daysMet++;
    }

    final doc = pw.Document();

    doc.addPage(
      pw.Page(
        build: (_) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text('FocusFlow Report', style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 8),
            pw.Text('Range: $startYmd to $endYmd'),
            pw.SizedBox(height: 16),
            pw.Text('Summary', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 6),
            pw.Text('Total focus: $totalMinutes minutes'),
            pw.Text('Total sessions: $totalSessions'),
            pw.Text('Goal met days: $daysMet / ${rows.length}'),
            pw.SizedBox(height: 16),
            pw.Text('Daily Breakdown', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 8),
            pw.Table.fromTextArray(
              headers: ['Date', 'Minutes', 'Sessions', 'Score', 'Goal'],
              data: rows.map((r) {
                final date = r['date'] ?? '';
                final mins = ((((r['totalFocusSeconds'] ?? 0) as num).toInt()) / 60).floor();
                final sessions = ((r['sessionsCount'] ?? 0) as num).toInt();
                final score = ((r['focusScore'] ?? 0) as num).toInt();
                final goal = (r['goalMet'] == true) ? 'Yes' : 'No';
                return [date, '$mins', '$sessions', '$score', goal];
              }).toList(),
            )
          ],
        ),
      ),
    );

    final dir = await getApplicationDocumentsDirectory();
    final file = File('${dir.path}/focusflow_$startYmd-to-$endYmd.pdf');
    await file.writeAsBytes(await doc.save());
    return file;
  }

  Future<void> shareFile(File file) async {
    await Share.shareXFiles([XFile(file.path)], text: 'FocusFlow export');
  }
}
