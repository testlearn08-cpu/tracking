import 'package:cloud_firestore/cloud_firestore.dart';
import '../core/kolkata_time.dart';
import 'stats_service.dart';

class StartedSession {
  final String sessionId;
  final Timestamp startedAt;
  final String localDate;
  StartedSession(this.sessionId, this.startedAt, this.localDate);
}

class SessionService {
  SessionService({required this.db, required this.statsService});
  final FirebaseFirestore db;
  final StatsService statsService;

  DocumentReference<Map<String, dynamic>> _userRef(String uid) =>
      db.collection('users').doc(uid);

  CollectionReference<Map<String, dynamic>> _sessionsCol(String uid) =>
      _userRef(uid).collection('sessions');

  Future<StartedSession> startSession({
    required String uid,
    required String intent,
    String? category,
    required int presetMinutes,
    required int breakMinutes,
    bool autoBreak = true,
  }) async {
    final id = _sessionsCol(uid).doc().id;
    final ref = _sessionsCol(uid).doc(id);

    final localDate = localDateKolkataYmd();
    final startedAt = Timestamp.now();

    await ref.set({
      'intent': intent.trim(),
      'category': category,
      'presetMinutes': presetMinutes,
      'breakMinutes': breakMinutes,
      'autoBreak': autoBreak,
      'status': 'running',
      'result': null,
      'startedAt': startedAt,
      'endedAt': null,
      'actualFocusSeconds': 0,
      'overtimeSeconds': 0,
      'distractionLevel': null,
      'distractors': <String>[],
      'notes': '',
      'device': 'android',
      'localDate': localDate,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),

      // ✅ guard
      'statsApplied': false,
    });

    return StartedSession(id, startedAt, localDate);
  }

  /// ✅ endSession is now idempotent for stats.
  Future<void> endSession({
    required String uid,
    required String sessionId,
    required DateTime startedAt,
    required int plannedFocusSeconds,
    required bool endedNormally,
    required int totalPausedSeconds,
  }) async {
    final ref = _sessionsCol(uid).doc(sessionId);
    final end = DateTime.now();

    int actual = end.difference(startedAt).inSeconds - totalPausedSeconds;
    if (actual < 0) actual = 0;

    int overtime = 0;
    if (actual > plannedFocusSeconds) overtime = actual - plannedFocusSeconds;

    if (!endedNormally) {
      overtime = 0;
      if (actual > plannedFocusSeconds) actual = plannedFocusSeconds;
    }

    // ✅ Transaction: update session + apply stats ONLY if not applied yet.
    bool shouldApplyStats = false;
    String sessionLocalDate = localDateKolkataYmd();

    await db.runTransaction((tx) async {
      final snap = await tx.get(ref);
      if (!snap.exists) throw StateError('Session not found');

      final data = snap.data() as Map<String, dynamic>;
      sessionLocalDate = (data['localDate'] as String?) ?? sessionLocalDate;

      final alreadyApplied = (data['statsApplied'] as bool?) ?? false;

      // Update session end fields
      tx.update(ref, {
        'endedAt': Timestamp.fromDate(end),
        'actualFocusSeconds': actual,
        'overtimeSeconds': overtime,
        'status': endedNormally ? 'completed' : 'cancelled',
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // Only apply stats once for completed sessions with >0 focus
      if (endedNormally && actual > 0 && !alreadyApplied) {
        tx.update(ref, {'statsApplied': true});
        shouldApplyStats = true;
      }
    });

    if (shouldApplyStats) {
      await statsService.applySessionToDailyStatsAndStreak(
        uid: uid,
        sessionFocusSeconds: actual,
        sessionResult: null,
        distractionLevel: null,
      );
    } else {
      // If stats weren't applied (duplicate call or cancelled), keep stats consistent
      await statsService.recomputeDailyStatsForDate(uid: uid, ymd: sessionLocalDate);
      await statsService.recomputeStreak(uid: uid);
    }
  }

  Future<void> submitFeedbackAndUpdateStats({
    required String uid,
    required String sessionId,
    required String result, // done|partial|not_done
    required int distractionLevel,
    List<String> distractors = const [],
    String notes = '',
  }) async {
    final ref = _sessionsCol(uid).doc(sessionId);
    final snap = await ref.get();
    if (!snap.exists) throw StateError('Session not found');

    await ref.update({
      'result': result,
      'distractionLevel': distractionLevel,
      'distractors': distractors,
      'notes': notes,
      'updatedAt': FieldValue.serverTimestamp(),
    });

    // ✅ Recompute day stats because result/distraction influences focusScore
    final localDate = (snap.data()?['localDate'] as String?) ?? localDateKolkataYmd();
    await statsService.recomputeDailyStatsForDate(uid: uid, ymd: localDate);
    await statsService.recomputeStreak(uid: uid);
  }

  /// ✅ Delete a session + recompute that day's stats.
  Future<void> deleteSession({
    required String uid,
    required String sessionId,
  }) async {
    final ref = _sessionsCol(uid).doc(sessionId);
    final snap = await ref.get();
    if (!snap.exists) return;

    final localDate = (snap.data()?['localDate'] as String?) ?? localDateKolkataYmd();

    await ref.delete();

    await statsService.recomputeDailyStatsForDate(uid: uid, ymd: localDate);
    await statsService.recomputeStreak(uid: uid);
  }
}
