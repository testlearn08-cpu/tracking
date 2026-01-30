import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/reports_service.dart';
import '../services/export_service.dart';
import '../core/kolkata_time.dart';

class ReportsScreen extends StatelessWidget {
  const ReportsScreen({super.key, required this.uid});
  final String uid;

  String _subtractDays(String ymd, int days) {
    final parts = ymd.split('-').map(int.parse).toList();
    final dt = DateTime(parts[0], parts[1], parts[2]).subtract(Duration(days: days));
    final y = dt.year.toString().padLeft(4, '0');
    final m = dt.month.toString().padLeft(2, '0');
    final d = dt.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }

  @override
  Widget build(BuildContext context) {
    final reports = context.read<ReportsService>();
    final export = context.read<ExportService>();

    final today = localDateKolkataYmd();
    final start = _subtractDays(today, 6);

    return Scaffold(
      appBar: AppBar(title: const Text('Reports')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: () async {
                      final file = await export.exportCsv(uid: uid, startYmd: start, endYmd: today);
                      await export.shareFile(file);
                    },
                    child: const Text('Export CSV'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () async {
                      final file = await export.exportPdf(uid: uid, startYmd: start, endYmd: today);
                      await export.shareFile(file);
                    },
                    child: const Text('Export PDF'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Expanded(
              child: FutureBuilder(
                future: reports.getDailyStatsRange(uid: uid, startYmd: start, endYmd: today),
                builder: (context, snap) {
                  final list = snap.data ?? [];
                  if (list.isEmpty) return const Center(child: Text('No data yet'));

                  return ListView.builder(
                    itemCount: list.length,
                    itemBuilder: (_, i) {
                      final d = list[i];
                      final date = d['date'] ?? '';
                      final min = ((d['totalFocusSeconds'] ?? 0) as num).toInt() ~/ 60;
                      final score = ((d['focusScore'] ?? 0) as num).toInt();
                      final goalMet = d['goalMet'] == true;
                      return ListTile(
                        title: Text(date),
                        subtitle: Text('$min min • score $score'),
                        trailing: Icon(goalMet ? Icons.check_circle : Icons.radio_button_unchecked),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
