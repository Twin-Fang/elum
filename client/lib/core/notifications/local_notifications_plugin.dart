import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../logger/app_logger.dart';

/// 기기 알림 플러그인 하나: 초기화 1회 + 알림 누름 스트림 (일과 알림·푸시 전경 배너가 함께 씀)
/// 플러그인 초기화는 앱 전체에서 하나만 유효해서(콜백이 덮어써짐) 한 곳에서만 부름
class LocalNotificationsPlugin {
  LocalNotificationsPlugin({FlutterLocalNotificationsPlugin? plugin})
    : plugin = plugin ?? FlutterLocalNotificationsPlugin();

  final FlutterLocalNotificationsPlugin plugin;

  // 상단바 작은 아이콘 (런처 아이콘 재사용)
  static const _androidIcon = '@mipmap/ic_launcher';

  final _tapController = StreamController<String>.broadcast();
  Future<void>? _initializing;

  /// 알림을 눌렀을 때의 payload (비어 있으면 흘리지 않음). 앱이 떠 있거나 백그라운드일 때만 옴
  Stream<String> get onNotificationTapped => _tapController.stream;

  /// 첫 호출 때 한 번만 초기화 (실패하면 다음 호출에서 다시 시도)
  Future<void> ensureInitialized() =>
      _initializing ??= _initialize().catchError((Object e) {
        _initializing = null;
        throw e;
      });

  Future<void> _initialize() async {
    await plugin.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings(_androidIcon),
        // 권한은 알림을 처음 켤 때 묻는다 (앱 시작 때 묻지 않음)
        iOS: DarwinInitializationSettings(
          requestAlertPermission: false,
          requestSoundPermission: false,
          requestBadgePermission: false,
        ),
      ),
      onDidReceiveNotificationResponse: _onResponse,
    );
  }

  void _onResponse(NotificationResponse response) {
    final payload = response.payload;
    if (payload == null || payload.isEmpty) return;
    _tapController.add(payload);
  }

  /// 알림을 눌러 종료 상태에서 앱이 열렸다면 그 payload (아니면 null)
  Future<String?> launchPayload() async {
    await ensureInitialized();
    final details = await plugin.getNotificationAppLaunchDetails();
    if (details == null || !details.didNotificationLaunchApp) return null;
    final payload = details.notificationResponse?.payload;
    return (payload == null || payload.isEmpty) ? null : payload;
  }

  /// 안드로이드 알림 채널 만들기 (이미 있으면 이름만 갱신됨, iOS 는 무시)
  Future<void> createAndroidChannel(AndroidNotificationChannel channel) async {
    if (defaultTargetPlatform != TargetPlatform.android) return;
    await ensureInitialized();
    await plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.createNotificationChannel(channel);
  }

  /// 즉시 알림 하나 띄우기
  Future<void> show({
    required int id,
    required String title,
    required String body,
    required String payload,
    required AndroidNotificationChannel channel,
  }) async {
    await ensureInitialized();
    await plugin.show(
      id: id,
      title: title,
      body: body,
      payload: payload,
      notificationDetails: NotificationDetails(
        android: AndroidNotificationDetails(
          channel.id,
          channel.name,
          importance: channel.importance,
          priority: Priority.high,
        ),
        iOS: const DarwinNotificationDetails(),
      ),
    );
    AppLogger.info('[notification] shown id=$id channel=${channel.id}');
  }
}

final localNotificationsPluginProvider = Provider<LocalNotificationsPlugin>(
  (ref) => LocalNotificationsPlugin(),
);
