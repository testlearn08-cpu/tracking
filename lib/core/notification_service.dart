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

  Future<void> init() async {
    tzdata.initializeTimeZones();

    // flutter_timezone can return either a String or TimezoneInfo depending on version.
    // Your current usage expects an object with .identifier — keep it safe:
    final tzInfo = await FlutterTimezone.getLocalTimezone();
    final String tzName = (tzInfo is String) ? tzInfo : tzInfo.identifier;

    tz.setLocalLocation(tz.getLocation(tzName));

    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const initSettings = InitializationSettings(android: androidInit);

    await _plugin.initialize(initSettings);

    final androidPlugin =
        _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();

    // ✅ Android 13+ permission (safe no-op on older)
    await androidPlugin?.requestNotificationsPermission();

    // ✅ Android 12+ exact alarms permission (recommended for exactAllowWhileIdle)
    // If not granted, some devices may delay notifications.
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
