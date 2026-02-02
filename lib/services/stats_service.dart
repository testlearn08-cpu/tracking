import 'package:cloud_firestore/cloud_firestore.dart';
import '../core/kolkata_time.dart';

class StatsService {
  StatsService(this.db);
  final FirebaseFirestore db;

  int _clamp(int v, int min, int max) => v < min ? min : (v > max ? max : v);

  int computeFocusScore({
    required int totalFocusSeconds,
    required int goalMinutes,
    required int doneCount,
    required int partialCount,
    required int notDoneCount,
    required int distractionSum,
    required int distractionCount,
  }) {
    final totalFocusMinutes = (totalFocusSeconds / 60).floor();
    final goal = goalMinutes <= 0 ? 120 : goalMinutes;

    final progress = (totalFocusMinutes / goal).clamp(0.0, 1.0);
    final minutesScore = (60 * progress).round();

    final totalRated = doneCount + partialCount + notDoneCount;
    int completionScore = 0;
    if (totalRated > 0) {
      final completionRatio = (doneCount * 1.0 + partialCount * 0.5) / totalRated;
      completionScore = (25 * completionRatio).round();
    }

    int distractionScore = 10;
    if (distractionCount > 0) {
      final avg = distractionSum / distractionCount;
      final mapped = ((5.0 - avg) / 4.0).clamp(0.0, 1.0);
      distractionScore = (15 * mapped).round();
    }

    return _clamp(minutesScore + completionScore + distractionScore, 0, 100);
  }

  /// ✅ Apply a session to today's stats ONLY ONCE (endSession uses guard now).
  Future<void> applySessionToDailyStatsAndStreak({
    required String uid,
    required int sessionFocusSeconds,
    String? sessionResult,
    int? distractionLevel,
  }) async {
    if (sessionFocusSeconds <= 0) return;

    final today = localDateKolkataYmd();
    final userRef = db.collection('users').doc(uid);
    final dailyRef = userRef.collection('dailyStats').doc(today);

    await db.runTransaction((tx) async {
      final userSnap = await tx.get(userRef);
      if (!userSnap.exists) throw StateError('User doc missing');

      final userData = userSnap.data() as Map<String, dynamic>;
      final goalMinutes = (userData['goalMinutes'] as num?)?.toInt() ?? 120;

      final dailySnap = await tx.get(dailyRef);
      final dailyData = (dailySnap.data() as Map<String, dynamic>?) ?? {};

      final prevTotal = (dailyData['totalFocusSeconds'] as num?)?.toInt() ?? 0;
      final prevCount = (dailyData['sessionsCount'] as num?)?.toInt() ?? 0;

      int doneCount = (dailyData['doneCount'] as num?)?.toInt() ?? 0;
      int partialCount = (dailyData['partialCount'] as num?)?.toInt() ?? 0;
      int notDoneCount = (dailyData['notDoneCount'] as num?)?.toInt() ?? 0;

      int distractionSum = (dailyData['distractionSum'] as num?)?.toInt() ?? 0;
      int distractionCount = (dailyData['distractionCount'] as num?)?.toInt() ?? 0;

      if (sessionResult == 'done') doneCount++;
      if (sessionResult == 'partial') partialCount++;
      if (sessionResult == 'not_done') notDoneCount++;

      if (distractionLevel != null && distractionLevel >= 1 && distractionLevel <= 5) {
        distractionSum += distractionLevel;
        distractionCount += 1;
      }

      final newTotal = prevTotal + sessionFocusSeconds;
      final newSessions = prevCount + 1;

      final goalSeconds = goalMinutes * 60;
      final newGoalMet = newTotal >= goalSeconds;

      final focusScore = computeFocusScore(
        totalFocusSeconds: newTotal,
        goalMinutes: goalMinutes,
        doneCount: doneCount,
        partialCount: partialCount,
        notDoneCount: notDoneCount,
        distractionSum: distractionSum,
        distractionCount: distractionCount,
      );

      final dailyUpdate = <String, dynamic>{
        'date': today,
        'totalFocusSeconds': newTotal,
        'sessionsCount': newSessions,
        'goalMet': newGoalMet,
        'focusScore': focusScore,
        'doneCount': doneCount,
        'partialCount': partialCount,
        'notDoneCount': notDoneCount,
        'distractionSum': distractionSum,
        'distractionCount': distractionCount,
        'updatedAt': FieldValue.serverTimestamp(),
      };
      if (!dailySnap.exists) dailyUpdate['createdAt'] = FieldValue.serverTimestamp();

      tx.set(dailyRef, dailyUpdate, SetOptions(merge: true));
    });

    // ✅ streak is recomputed safely (handles deletes/edits)
    await recomputeStreak(uid: uid);
  }

  /// ✅ Recompute stats for a given date by scanning sessions collection.
  Future<void> recomputeDailyStatsForDate({
    required String uid,
    required String ymd,
  }) async {
    final userRef = db.collection('users').doc(uid);
    final dailyRef = userRef.collection('dailyStats').doc(ymd);

    // Read goal from user
    final userSnap = await userRef.get();
    final goalMinutes = (userSnap.data()?['goalMinutes'] as num?)?.toInt() ?? 120;

    // Query sessions for that date
    final sessionsSnap = await userRef
        .collection('sessions')
        .where('localDate', isEqualTo: ymd)
        .get();

    int totalFocusSeconds = 0;
    int sessionsCount = 0;

    int doneCount = 0;
    int partialCount = 0;
    int notDoneCount = 0;

    int distractionSum = 0;
    int distractionCount = 0;

    for (final doc in sessionsSnap.docs) {
      final d = doc.data();
      final status = (d['status'] ?? '') as String;

      // Only count completed sessions
      if (status != 'completed') continue;

      final actualSec = ((d['actualFocusSeconds'] ?? 0) as num).toInt();
      if (actualSec <= 0) continue;

      totalFocusSeconds += actualSec;
      sessionsCount += 1;

      final result = (d['result'] ?? '') as String;
      if (result == 'done') doneCount++;
      if (result == 'partial') partialCount++;
      if (result == 'not_done') notDoneCount++;

      final dis = (d['distractionLevel'] as num?)?.toInt();
      if (dis != null && dis >= 1 && dis <= 5) {
        distractionSum += dis;
        distractionCount += 1;
      }
    }

    final goalSeconds = goalMinutes * 60;
    final goalMet = totalFocusSeconds >= goalSeconds;

    final focusScore = computeFocusScore(
      totalFocusSeconds: totalFocusSeconds,
      goalMinutes: goalMinutes,
      doneCount: doneCount,
      partialCount: partialCount,
      notDoneCount: notDoneCount,
      distractionSum: distractionSum,
      distractionCount: distractionCount,
    );

    if (sessionsCount == 0 && totalFocusSeconds == 0) {
      // If no sessions remain, delete stats doc (optional)
      await dailyRef.delete().catchError((_) {});
    } else {
      await dailyRef.set({
        'date': ymd,
        'totalFocusSeconds': totalFocusSeconds,
        'sessionsCount': sessionsCount,
        'goalMet': goalMet,
        'focusScore': focusScore,
        'doneCount': doneCount,
        'partialCount': partialCount,
        'notDoneCount': notDoneCount,
        'distractionSum': distractionSum,
        'distractionCount': distractionCount,
        'updatedAt': FieldValue.serverTimestamp(),
        'createdAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    }
  }

  /// ✅ Robust streak recompute: reads last ~60 days and counts consecutive goalMet ending today.
  Future<void> recomputeStreak({required String uid}) async {
    final userRef = db.collection('users').doc(uid);

    // Pull last 60 days of dailyStats
    final dailySnap = await userRef
        .collection('dailyStats')
        .orderBy('date', descending: true)
        .limit(60)
        .get();

    final Map<String, bool> goalMetByDate = {};
    for (final doc in dailySnap.docs) {
      final d = doc.data();
      final date = (d['date'] ?? doc.id) as String;
      final met = (d['goalMet'] as bool?) ?? false;
      goalMetByDate[date] = met;
    }

    // Build streak from today backwards (Kolkata)
    String current = localDateKolkataYmd();
    int streak = 0;

    while (true) {
      final met = goalMetByDate[current] == true;
      if (!met) break;
      streak += 1;

      // move to previous day
      final parts = current.split('-').map(int.parse).toList();
      final dt = DateTime(parts[0], parts[1], parts[2]).subtract(const Duration(days: 1));
      current =
          '${dt.year.toString().padLeft(4, '0')}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
    }

    final lastGoalMetDate = streak > 0 ? localDateKolkataYmd() : null;

    await userRef.set({
      'streakCount': streak,
      'lastGoalMetDate': lastGoalMetDate,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }
}
