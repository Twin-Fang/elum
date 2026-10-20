import 'package:app_settings/app_settings.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// 기기 알림 권한: 확인, 요청, 기기 설정 화면 열기
abstract interface class NotificationPermissionGate {
  Future<bool> isGranted();

  /// 시스템 권한 창 요청 > 허용 여부
  Future<bool> request();

  Future<void> openDeviceSettings();
}

/// 권한 조회 전용 플러그인 인스턴스 사용 (초기화·예약은 reminder 쪽 몫)
class LocalNotificationPermissionGate implements NotificationPermissionGate {
  LocalNotificationPermissionGate({FlutterLocalNotificationsPlugin? plugin})
      : _plugin = plugin ?? FlutterLocalNotificationsPlugin();

  final FlutterLocalNotificationsPlugin _plugin;

  AndroidFlutterLocalNotificationsPlugin? get _android =>
      _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();

  IOSFlutterLocalNotificationsPlugin? get _ios =>
      _plugin.resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin>();

  @override
  Future<bool> isGranted() async {
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return await _android?.areNotificationsEnabled() ?? false;
      case TargetPlatform.iOS:
        return (await _ios?.checkPermissions())?.isEnabled ?? false;
      default:
        // 그 외 플랫폼은 안내 줄을 띄우지 않음
        return true;
    }
  }

  @override
  Future<bool> request() async {
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return await _android?.requestNotificationsPermission() ?? false;
      case TargetPlatform.iOS:
        return await _ios?.requestPermissions(
              alert: true,
              badge: false,
              sound: true,
            ) ??
            false;
      default:
        return true;
    }
  }

  @override
  Future<void> openDeviceSettings() =>
      AppSettings.openAppSettings(type: AppSettingsType.notification);
}

final notificationPermissionGateProvider = Provider<NotificationPermissionGate>(
  (ref) => LocalNotificationPermissionGate(),
);
