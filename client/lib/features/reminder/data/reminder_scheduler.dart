import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

import '../../../core/logger/app_logger.dart';
import '../domain/routine_reminder.dart';

/// 알림 글 (기기 언어로 부르는 쪽이 채운다)
typedef ReminderTexts = ({String channelName, String title, String body});

/// 기기 알림 예약 창구 (#777). 테스트에서 가짜로 바꿔 끼운다
abstract interface class ReminderScheduler {
  /// 알림 권한 요청. 이미 허용이면 묻지 않고 true
  Future<bool> requestPermission();

  /// [reminder] 시각에 예약 (같은 일과의 이전 예약은 덮어쓴다)
  Future<void> schedule(RoutineReminder reminder, ReminderTexts texts);

  Future<void> cancel(RoutineReminder reminder);
}

/// flutter_local_notifications 구현: 첫 사용 때 초기화(시간대 포함) > 예약
class LocalNotificationReminderScheduler implements ReminderScheduler {
  LocalNotificationReminderScheduler({FlutterLocalNotificationsPlugin? plugin})
    : _plugin = plugin ?? FlutterLocalNotificationsPlugin();

  final FlutterLocalNotificationsPlugin _plugin;
  Future<void>? _initializing;

  // 안드로이드 알림 채널 id (한 번 만들면 이름 외엔 바꿀 수 없다)
  static const _channelId = 'routine_reminder';

  // 상단바 작은 아이콘 (런처 아이콘 재사용)
  static const _androidIcon = '@mipmap/ic_launcher';

  Future<void> _ensureInitialized() =>
      _initializing ??= _initialize().catchError((Object e) {
        // 다음 호출에서 다시 시도
        _initializing = null;
        throw e;
      });

  Future<void> _initialize() async {
    // 시간대: 기기 시간대 > 실패하면 서울 (서비스 지역)
    tz_data.initializeTimeZones();
    try {
      final local = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(local.identifier));
    } catch (e) {
      AppLogger.error('reminder', 'timezone lookup failed → Asia/Seoul: $e');
      tz.setLocalLocation(tz.getLocation('Asia/Seoul'));
    }
    await _plugin.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings(_androidIcon),
        // 권한은 알림을 처음 켤 때 묻는다 (앱 시작 때 묻지 않음)
        iOS: DarwinInitializationSettings(
          requestAlertPermission: false,
          requestSoundPermission: false,
          requestBadgePermission: false,
        ),
      ),
    );
  }

  @override
  Future<bool> requestPermission() async {
    await _ensureInitialized();
    if (defaultTargetPlatform == TargetPlatform.android) {
      final android = _plugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();
      if (await android?.areNotificationsEnabled() == true) return true;
      return await android?.requestNotificationsPermission() ?? false;
    }
    final ios = _plugin
        .resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin
        >();
    return await ios?.requestPermissions(alert: true, sound: true) ?? false;
  }

  @override
  Future<void> schedule(RoutineReminder reminder, ReminderTexts texts) async {
    await _ensureInitialized();
    final next = reminder.nextFireAfter(DateTime.now());
    final at = tz.TZDateTime(
      tz.local,
      next.year,
      next.month,
      next.day,
      next.hour,
      next.minute,
    );
    await _plugin.zonedSchedule(
      id: reminder.notificationId,
      scheduledDate: at,
      title: texts.title,
      body: texts.body,
      payload: reminder.routineId,
      notificationDetails: NotificationDetails(
        android: AndroidNotificationDetails(
          _channelId,
          texts.channelName,
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: const DarwinNotificationDetails(),
      ),
      androidScheduleMode: await _androidScheduleMode(),
      // 매일이면 시:분만 맞춰 반복
      matchDateTimeComponents: reminder.isDaily
          ? DateTimeComponents.time
          : null,
    );
    AppLogger.info(
      '[reminder] scheduled id=${reminder.notificationId} at=$at daily=${reminder.isDaily}',
    );
  }

  /// 정확한 알람 허용이면 정시, 아니면 몇 분 늦을 수 있는 방식 (권한을 따로 조르지 않는다)
  Future<AndroidScheduleMode> _androidScheduleMode() async {
    if (defaultTargetPlatform != TargetPlatform.android) {
      return AndroidScheduleMode.exactAllowWhileIdle;
    }
    try {
      final android = _plugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();
      final canExact = await android?.canScheduleExactNotifications() ?? false;
      return canExact
          ? AndroidScheduleMode.exactAllowWhileIdle
          : AndroidScheduleMode.inexactAllowWhileIdle;
    } catch (e) {
      AppLogger.error('reminder', 'exact alarm check failed → inexact: $e');
      return AndroidScheduleMode.inexactAllowWhileIdle;
    }
  }

  @override
  Future<void> cancel(RoutineReminder reminder) async {
    await _ensureInitialized();
    await _plugin.cancel(id: reminder.notificationId);
  }
}
