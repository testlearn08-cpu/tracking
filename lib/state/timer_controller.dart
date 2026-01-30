import 'dart:async';
import '../core/local_timer_store.dart';

enum TimerPhase { focusing, breakTime, idle }
enum TimerStatus { running, paused, stopped }

class ActiveTimerModel {
  final String uid;
  final String sessionId;
  final String intent;
  final int focusSeconds;
  final int breakSeconds;
  final bool autoBreak;

  final TimerPhase phase;
  final TimerStatus status;

  final int phaseStartEpochMs;
  final int phaseDurationSeconds;
  final int totalPausedSeconds;
  final int? pauseStartedEpochMs;

  const ActiveTimerModel({
    required this.uid,
    required this.sessionId,
    required this.intent,
    required this.focusSeconds,
    required this.breakSeconds,
    required this.autoBreak,
    required this.phase,
    required this.status,
    required this.phaseStartEpochMs,
    required this.phaseDurationSeconds,
    required this.totalPausedSeconds,
    required this.pauseStartedEpochMs,
  });

  Map<String, dynamic> toJson() => {
        'uid': uid,
        'sessionId': sessionId,
        'intent': intent,
        'focusSeconds': focusSeconds,
        'breakSeconds': breakSeconds,
        'autoBreak': autoBreak,
        'phase': phase.name,
        'status': status.name,
        'phaseStartEpochMs': phaseStartEpochMs,
        'phaseDurationSeconds': phaseDurationSeconds,
        'totalPausedSeconds': totalPausedSeconds,
        'pauseStartedEpochMs': pauseStartedEpochMs,
      };

  static ActiveTimerModel fromJson(Map<String, dynamic> j) => ActiveTimerModel(
        uid: j['uid'] as String,
        sessionId: j['sessionId'] as String,
        intent: j['intent'] as String,
        focusSeconds: (j['focusSeconds'] as num).toInt(),
        breakSeconds: (j['breakSeconds'] as num).toInt(),
        autoBreak: j['autoBreak'] as bool,
        phase: TimerPhase.values.firstWhere((e) => e.name == j['phase']),
        status: TimerStatus.values.firstWhere((e) => e.name == j['status']),
        phaseStartEpochMs: (j['phaseStartEpochMs'] as num).toInt(),
        phaseDurationSeconds: (j['phaseDurationSeconds'] as num).toInt(),
        totalPausedSeconds: (j['totalPausedSeconds'] as num).toInt(),
        pauseStartedEpochMs: (j['pauseStartedEpochMs'] as num?)?.toInt(),
      );

  int remainingSeconds() {
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    final elapsed = ((nowMs - phaseStartEpochMs) / 1000).floor() - totalPausedSeconds;
    return phaseDurationSeconds - elapsed;
  }
}

class TimerController {
  TimerController(this.store);

  final LocalTimerStore store;
  Timer? _ticker;
  ActiveTimerModel? active;

  final _stream = StreamController<int>.broadcast();
  Stream<int> get remainingStream => _stream.stream;

  void dispose() {
    _ticker?.cancel();
    _stream.close();
  }

  Future<void> restoreIfAny() async {
    final j = await store.load();
    if (j == null) return;
    active = ActiveTimerModel.fromJson(j);
    _startTicker();
  }

  Future<void> startFocus({
    required String uid,
    required String sessionId,
    required String intent,
    required int focusSeconds,
    required int breakSeconds,
    required bool autoBreak,
  }) async {
    active = ActiveTimerModel(
      uid: uid,
      sessionId: sessionId,
      intent: intent,
      focusSeconds: focusSeconds,
      breakSeconds: breakSeconds,
      autoBreak: autoBreak,
      phase: TimerPhase.focusing,
      status: TimerStatus.running,
      phaseStartEpochMs: DateTime.now().millisecondsSinceEpoch,
      phaseDurationSeconds: focusSeconds,
      totalPausedSeconds: 0,
      pauseStartedEpochMs: null,
    );
    await store.save(active!.toJson());
    _startTicker();
  }

  Future<void> pause() async {
    if (active == null || active!.status != TimerStatus.running) return;
    active = ActiveTimerModel(
      uid: active!.uid,
      sessionId: active!.sessionId,
      intent: active!.intent,
      focusSeconds: active!.focusSeconds,
      breakSeconds: active!.breakSeconds,
      autoBreak: active!.autoBreak,
      phase: active!.phase,
      status: TimerStatus.paused,
      phaseStartEpochMs: active!.phaseStartEpochMs,
      phaseDurationSeconds: active!.phaseDurationSeconds,
      totalPausedSeconds: active!.totalPausedSeconds,
      pauseStartedEpochMs: DateTime.now().millisecondsSinceEpoch,
    );
    await store.save(active!.toJson());
  }

  Future<void> resume() async {
    if (active == null || active!.status != TimerStatus.paused) return;
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    final pausedFor = ((nowMs - (active!.pauseStartedEpochMs ?? nowMs)) / 1000).floor();

    active = ActiveTimerModel(
      uid: active!.uid,
      sessionId: active!.sessionId,
      intent: active!.intent,
      focusSeconds: active!.focusSeconds,
      breakSeconds: active!.breakSeconds,
      autoBreak: active!.autoBreak,
      phase: active!.phase,
      status: TimerStatus.running,
      phaseStartEpochMs: active!.phaseStartEpochMs,
      phaseDurationSeconds: active!.phaseDurationSeconds,
      totalPausedSeconds: active!.totalPausedSeconds + pausedFor,
      pauseStartedEpochMs: null,
    );
    await store.save(active!.toJson());
  }

  Future<void> switchToBreak() async {
    if (active == null) return;
    active = ActiveTimerModel(
      uid: active!.uid,
      sessionId: active!.sessionId,
      intent: active!.intent,
      focusSeconds: active!.focusSeconds,
      breakSeconds: active!.breakSeconds,
      autoBreak: active!.autoBreak,
      phase: TimerPhase.breakTime,
      status: TimerStatus.running,
      phaseStartEpochMs: DateTime.now().millisecondsSinceEpoch,
      phaseDurationSeconds: active!.breakSeconds,
      totalPausedSeconds: 0,
      pauseStartedEpochMs: null,
    );
    await store.save(active!.toJson());
  }

  Future<void> clear() async {
    _ticker?.cancel();
    active = null;
    await store.clear();
  }

  void _startTicker() {
    _ticker?.cancel();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      final a = active;
      if (a == null) return;
      _stream.add(a.remainingSeconds());
    });
  }
}
