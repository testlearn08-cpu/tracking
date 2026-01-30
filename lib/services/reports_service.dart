import 'package:cloud_firestore/cloud_firestore.dart';

class ReportsService {
  ReportsService(this.db);
  final FirebaseFirestore db;

  Future<Map<String, dynamic>?> getDailyStats({
    required String uid,
    required String ymd,
  }) async {
    final ref = db.collection('users').doc(uid).collection('dailyStats').doc(ymd);
    final snap = await ref.get();
    return snap.data();
  }

  Future<List<Map<String, dynamic>>> getDailyStatsRange({
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
}
