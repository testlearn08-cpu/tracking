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

  /// Firestore transaction:
  /// - upserts dailyStats/{YYYY-MM-DD}
  /// - increments streak only once when goal becomes met for the day
  Future<void> applySessionToDailyStatsAndStreak({
    required String uid,
    required int sessionFocusSeconds,
    String? sessionResult,
    int? distractionLevel,
  }) async {
    if (sessionFocusSeconds <= 0) return;

    final today = localDateKolkataYmd();
    final yesterday = yesterdayKolkataYmd();

    final userRef = db.collection('users').doc(uid);
    final dailyRef = userRef.collection('dailyStats').doc(today);

    await db.runTransaction((tx) async {
      final userSnap = await tx.get(userRef);
      if (!userSnap.exists) throw StateError('User doc missing');

      final userData = userSnap.data() as Map<String, dynamic>;
      final goalMinutes = (userData['goalMinutes'] as num?)?.toInt() ?? 120;

      final currentStreak = (userData['streakCount'] as num?)?.toInt() ?? 0;
      final lastGoalMetDate = userData['lastGoalMetDate'] as String?;

      final dailySnap = await tx.get(dailyRef);
      final dailyData = (dailySnap.data() as Map<String, dynamic>?) ?? {};

      final prevTotal = (dailyData['totalFocusSeconds'] as num?)?.toInt() ?? 0;
      final prevCount = (dailyData['sessionsCount'] as num?)?.toInt() ?? 0;
      final prevGoalMet = (dailyData['goalMet'] as bool?) ?? false;

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

      // Streak increments only when:
      // - goal was NOT met earlier in day
      // - goal becomes met now
      // - and we haven't already counted today
      if (!prevGoalMet && newGoalMet && lastGoalMetDate != today) {
        final nextStreak = (lastGoalMetDate == yesterday) ? (currentStreak + 1) : 1;
        tx.update(userRef, {
          'streakCount': nextStreak,
          'lastGoalMetDate': today,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      } else {
        tx.update(userRef, {'updatedAt': FieldValue.serverTimestamp()});
      }
    });
  }
}
