import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:flutter_timezone/flutter_timezone.dart';

class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();

  static const String _channelId = 'focusflow_timer';
  static const String _channelName = 'FocusFlow Timer';

  static const AndroidNotificationDetails _androidDetails = AndroidNotificationDetails(
    _channelId,
    _channelName,
    channelDescription: 'Timer completion notifications',
    importance: Importance.max,
    priority: Priority.high,
  );

  /// Supports both flutter_timezone return types:
  /// - String (e.g. "Asia/Kolkata")
  /// - TimezoneInfo-like object with "identifier"
  String _extractTzName(Object tzInfo) {
    // If plugin returns String
    if (tzInfo is String) return tzInfo;

    // If plugin returns an object (TimezoneInfo) -> use dynamic safely
    try {
      final dynamic d = tzInfo;
      final String? id = d.identifier as String?;
      if (id != null && id.isNotEmpty) return id;
    } catch (_) {}

    // Fallback (works for most Android devices)
    return 'Asia/Kolkata';
  }

  Future<void> init() async {
    tzdata.initializeTimeZones();

    // flutter_timezone versions differ; treat result as Object
    final Object tzInfo = await FlutterTimezone.getLocalTimezone();
    final String tzName = _extractTzName(tzInfo);

    tz.setLocalLocation(tz.getLocation(tzName));

    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const initSettings = InitializationSettings(android: androidInit);

    await _plugin.initialize(initSettings);

    final androidPlugin =
        _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();

    // ✅ Android 13+ permission
    await androidPlugin?.requestNotificationsPermission();

    // ✅ Android 12+ exact alarm permission (recommended)
    await androidPlugin?.requestExactAlarmsPermission();
  }

  Future<void> cancelAll() => _plugin.cancelAll();

  Future<void> scheduleTimerDone({
    required int id,
    required Duration fromNow,
    required String title,
    required String body,
  }) async {
    final scheduled = tz.TZDateTime.now(tz.local).add(fromNow);

    await _plugin.zonedSchedule(
      id,
      title,
      body,
      scheduled,
      const NotificationDetails(android: _androidDetails),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: null,
    );
  }
}
