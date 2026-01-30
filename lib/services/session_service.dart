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

  DocumentReference<Map<String, dynamic>> _userRef(String uid) => db.collection('users').doc(uid);

  CollectionReference<Map<String, dynamic>> _sessionsCol(String uid) => _userRef(uid).collection('sessions');

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
    });

    return StartedSession(id, startedAt, localDate);
  }

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

    await ref.update({
      'endedAt': Timestamp.fromDate(end),
      'actualFocusSeconds': actual,
      'overtimeSeconds': overtime,
      'status': endedNormally ? 'completed' : 'cancelled',
      'updatedAt': FieldValue.serverTimestamp(),
    });
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

    final data = snap.data()!;
    final status = (data['status'] as String?) ?? 'running';
    final actual = (data['actualFocusSeconds'] as num?)?.toInt() ?? 0;

    await ref.update({
      'result': result,
      'distractionLevel': distractionLevel,
      'distractors': distractors,
      'notes': notes,
      'updatedAt': FieldValue.serverTimestamp(),
    });

    if (status == 'completed' && actual > 0) {
      await statsService.applySessionToDailyStatsAndStreak(
        uid: uid,
        sessionFocusSeconds: actual,
        sessionResult: result,
        distractionLevel: distractionLevel,
      );
    }
  }
}
