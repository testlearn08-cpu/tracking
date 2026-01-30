import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:flutter_timezone/flutter_timezone.dart';

class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();

  static const AndroidNotificationDetails _androidDetails = AndroidNotificationDetails(
    'focusflow_timer',
    'FocusFlow Timer',
    channelDescription: 'Timer completion notifications',
    importance: Importance.max,
    priority: Priority.high,
  );

  Future<void> init() async {
    tzdata.initializeTimeZones();

    // flutter_timezone 5.x returns TimezoneInfo with an IANA "identifier"
    // e.g. "Asia/Kolkata"
    final tzInfo = await FlutterTimezone.getLocalTimezone();
    final String tzName = tzInfo.identifier;

    tz.setLocalLocation(tz.getLocation(tzName));

    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const initSettings = InitializationSettings(android: androidInit);

    await _plugin.initialize(initSettings);

    // Android 13+ permission (safe: no-op on older)
    await _plugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();
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
