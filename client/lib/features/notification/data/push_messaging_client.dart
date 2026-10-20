// 서버가 FCM 토큰으로 발송하므로 getToken·onTokenRefresh·deleteToken 을 씀 (대체 API 는 FID 용이라 토큰이 다름)
// ignore_for_file: deprecated_member_use
import 'dart:async';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/push_message.dart';
import '../domain/push_permission_status.dart';

/// 푸시 수신 창구(FCM): 토큰, 권한, 받은 메시지. 테스트에서 가짜로 바꿔 끼운다
abstract interface class PushMessagingClient {
  /// 기기 토큰 (APNs 미등록 시뮬레이터·오프라인이면 던질 수 있음)
  Future<String?> getToken();

  Stream<String> get onTokenRefresh;

  Future<void> deleteToken();

  Future<PushPermissionStatus> permissionStatus();

  /// 시스템 권한 창 요청(iOS 는 APNs 등록 포함) > 허용 여부
  Future<bool> requestPermission();

  /// 앱이 떠 있을 때 받은 푸시
  Stream<PushMessage> get onForegroundMessage;

  /// 알림을 눌러 백그라운드에서 앱이 열린 경우
  Stream<PushMessage> get onMessageOpenedApp;

  /// 알림을 눌러 종료 상태에서 앱이 열린 경우 (없으면 null)
  Future<PushMessage?> getInitialMessage();

  /// iOS 전경 수신 시 시스템 배너·소리·배지를 끔 (배너는 로컬 알림 하나로 통일)
  Future<void> disableSystemForegroundPresentation();
}

class FirebasePushMessagingClient implements PushMessagingClient {
  FirebasePushMessagingClient({FirebaseMessaging? messaging})
    : _messaging = messaging ?? FirebaseMessaging.instance;

  final FirebaseMessaging _messaging;

  @override
  Future<String?> getToken() => _messaging.getToken();

  @override
  Stream<String> get onTokenRefresh => _messaging.onTokenRefresh;

  @override
  Future<void> deleteToken() => _messaging.deleteToken();

  @override
  Future<PushPermissionStatus> permissionStatus() async {
    final settings = await _messaging.getNotificationSettings();
    return _toStatus(settings.authorizationStatus);
  }

  @override
  Future<bool> requestPermission() async {
    final settings = await _messaging.requestPermission(
      alert: true,
      badge: false,
      sound: true,
    );
    return _toStatus(settings.authorizationStatus).isGranted;
  }

  @override
  Stream<PushMessage> get onForegroundMessage =>
      FirebaseMessaging.onMessage.map(_toPushMessage);

  @override
  Stream<PushMessage> get onMessageOpenedApp =>
      FirebaseMessaging.onMessageOpenedApp.map(_toPushMessage);

  @override
  Future<PushMessage?> getInitialMessage() async {
    final message = await _messaging.getInitialMessage();
    return message == null ? null : _toPushMessage(message);
  }

  @override
  Future<void> disableSystemForegroundPresentation() =>
      _messaging.setForegroundNotificationPresentationOptions(
        alert: false,
        badge: false,
        sound: false,
      );

  // authorized·provisional 은 허용, 안드로이드 12 이하는 항상 authorized
  PushPermissionStatus _toStatus(AuthorizationStatus status) =>
      switch (status) {
        AuthorizationStatus.authorized ||
        AuthorizationStatus.provisional => PushPermissionStatus.granted,
        AuthorizationStatus.denied ||
        AuthorizationStatus.deniedPermanently => PushPermissionStatus.denied,
        AuthorizationStatus.notDetermined => PushPermissionStatus.notDetermined,
      };

  PushMessage _toPushMessage(RemoteMessage message) => PushMessage(
    data: {
      for (final entry in message.data.entries)
        if (entry.value != null) entry.key: entry.value.toString(),
    },
    title: message.notification?.title,
    body: message.notification?.body,
  );
}

final pushMessagingClientProvider = Provider<PushMessagingClient>(
  (ref) => FirebasePushMessagingClient(),
);
