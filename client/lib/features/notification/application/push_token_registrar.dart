import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/logger/app_logger.dart';
import '../../auth/application/auth_session_controller.dart';
import '../data/push_device_repository.dart';
import '../data/push_messaging_client.dart';
import '../domain/push_platform.dart';

final pushTokenRegistrarProvider = Provider<PushTokenRegistrar>(
  PushTokenRegistrar.new,
);

/// 기기 푸시 토큰 등록·해제: 로그인 세션 + 알림 권한이 있을 때만 서버에 등록 (보호자·이룸이 기기 공통)
/// 이룸이 기기 구분은 서버가 토큰의 연결 ID 로 붙임
/// 토큰 갱신은 한 번만 구독하고, 모든 실패는 로그만 남기고 삼키지 않되 던지지도 않음 (앱 흐름을 막지 않음)
class PushTokenRegistrar {
  PushTokenRegistrar(this._ref);

  final Ref _ref;

  // 해제 때 서버·FCM 이 응답하지 않아도 로그아웃을 막지 않는 상한
  static const _unregisterStepTimeout = Duration(seconds: 5);

  StreamSubscription<String>? _refreshSubscription;

  /// 이번 실행에서 서버 등록에 성공한 토큰 (같은 토큰 재등록 방지)
  String? _registeredToken;

  /// 해제 후 ~ 다음 동기화 전: 토큰 갱신 이벤트로 되살아나지 않게 막음
  bool _isSuspended = false;

  /// 등록 작업을 한 줄로 세움 (동시 호출·토큰 갱신 연타 방지)
  Future<void> _queue = Future<void>.value();

  PushMessagingClient get _client => _ref.read(pushMessagingClientProvider);

  /// 조건이 맞으면 현재 토큰 등록 + 갱신 구독 (로그인 직후, 앱 시작, 권한 허용 직후에 부름)
  Future<void> syncRegistration() async {
    _isSuspended = false;
    // 명시적 동기화는 서버 PUT 을 항상 다시 함 (세션 만료로 다른 계정이 들어온 경우 토큰 주인을 바로잡음)
    _registeredToken = null;
    try {
      _subscribeToTokenRefresh();
    } catch (e, st) {
      // Firebase 초기화 실패 등: 푸시만 꺼진 채로 앱은 계속
      AppLogger.error('push', e, st, {'step': 'subscribeTokenRefresh'});
      return;
    }
    await _enqueue(() => _registerCurrentToken());
  }

  /// 로그아웃·회원삭제·이룸이 기기 전환 직전: 서버 해제 > 기기 토큰 삭제 (각 단계 실패해도 다음 단계 진행)
  Future<void> unregisterBeforeSignOut() {
    _isSuspended = true;
    return _enqueue(() async {
      final token = await _tokenToUnregister();
      if (token != null &&
          _ref.read(authSessionControllerProvider).hasSession) {
        try {
          await _ref
              .read(pushDeviceRepositoryProvider)
              .unregister(token)
              .timeout(_unregisterStepTimeout);
        } catch (e, st) {
          AppLogger.error('push', e, st, {'step': 'unregisterServer'});
        }
      }
      _registeredToken = null;
      try {
        await _client.deleteToken().timeout(_unregisterStepTimeout);
      } catch (e, st) {
        AppLogger.error('push', e, st, {'step': 'deleteToken'});
      }
    });
  }

  void _subscribeToTokenRefresh() {
    _refreshSubscription ??= _client.onTokenRefresh.listen(
      (token) => _enqueue(() => _registerToken(token)),
      onError: (Object e, StackTrace st) =>
          AppLogger.error('push', e, st, {'step': 'tokenRefresh'}),
    );
  }

  // 등록할 조건: 로그인 세션 + 알림 권한
  Future<bool> _canRegister() async {
    if (_isSuspended) return false;
    if (!_ref.read(authSessionControllerProvider).hasSession) return false;
    try {
      return (await _client.permissionStatus()).isGranted;
    } catch (e, st) {
      AppLogger.error('push', e, st, {'step': 'permissionStatus'});
      return false;
    }
  }

  Future<void> _registerCurrentToken() async {
    if (!await _canRegister()) return;
    final String? token;
    try {
      token = await _client.getToken();
    } catch (e, st) {
      // APNs 미등록 시뮬레이터, 오프라인 등: 다음 동기화·토큰 갱신 때 다시 시도
      AppLogger.error('push', e, st, {'step': 'getToken'});
      return;
    }
    if (token == null || token.isEmpty) return;
    await _registerToken(token, isConditionChecked: true);
  }

  Future<void> _registerToken(
    String token, {
    bool isConditionChecked = false,
  }) async {
    if (token == _registeredToken) return;
    if (!isConditionChecked && !await _canRegister()) return;
    try {
      await _ref.read(pushDeviceRepositoryProvider).register(token, _platform);
      _registeredToken = token;
    } catch (e, st) {
      AppLogger.error('push', e, st, {'step': 'registerServer'});
    }
  }

  // 해제할 토큰: 등록해 둔 것, 없으면 지금 토큰 (실패하면 서버 해제 생략)
  Future<String?> _tokenToUnregister() async {
    final registered = _registeredToken;
    if (registered != null) return registered;
    try {
      return await _client.getToken().timeout(_unregisterStepTimeout);
    } catch (e, st) {
      AppLogger.error('push', e, st, {'step': 'getTokenForUnregister'});
      return null;
    }
  }

  PushPlatform get _platform =>
      Platform.isIOS ? PushPlatform.ios : PushPlatform.android;

  Future<void> _enqueue(Future<void> Function() task) {
    final next = _queue.then((_) => task()).catchError((
      Object e,
      StackTrace st,
    ) {
      // 작업 안에서 모두 처리하지만, 예기치 못한 예외도 다음 작업을 막지 않게 기록
      AppLogger.error('push', e, st, {'step': 'queue'});
    });
    _queue = next;
    return next;
  }
}
