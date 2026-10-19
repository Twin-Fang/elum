import 'dart:async';
import 'dart:convert';

import 'package:flutter/widgets.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/l10n/current_l10n.dart';
import '../../../core/logger/app_logger.dart';
import '../../../core/notifications/local_notifications_plugin.dart';
import '../../../core/router/routes.dart';
import '../../../core/storage/local_storage.dart';
import '../../auth/application/auth_session_controller.dart';
import '../data/notification_repository.dart';
import '../data/push_messaging_client.dart';
import '../domain/push_message.dart';
import 'notification_navigator.dart';
import 'notification_target.dart';
import 'pending_push_open.dart';
import 'unread_summary_provider.dart';

final pushMessageRouterProvider = Provider<PushMessageRouter>(
  PushMessageRouter.new,
);

/// 앱을 열 수 있는 상태일 때만 네비게이터 컨텍스트를 돌려주는 함수 (아니면 null)
/// 보호자 화면 안에 있어야 이동해도 로그인·역할 선택 흐름을 건너뛰지 않음
typedef ReadyNavigatorContext = BuildContext? Function();

/// 푸시 수신 > 화면 반영: 전경 수신(안 읽음 갱신 + 배너), 알림 누름(앱 열기·로컬 배너) > 해당 화면 이동
/// 이동은 보호자로 로그인했고 화면이 준비된 뒤 한 번만, 로그인 전에 누른 알림은 버림
class PushMessageRouter {
  PushMessageRouter(this._ref);

  final Ref _ref;

  // 배너용 안드로이드 채널 id (AndroidManifest 의 FCM 기본 채널과 같음)
  static const _guardianUpdatesChannelId = 'guardian_updates';

  // 눌렀지만 화면이 준비되지 않았을 때 기다려 주는 시간 (그 뒤엔 낡은 이동이라 버림)
  static const _pendingOpenValidity = Duration(seconds: 30);

  // 같은 알림이 두 경로(초기 메시지·누름 스트림)로 들어와도 한 번만 여는 시간
  static const _duplicateOpenWindow = Duration(seconds: 5);

  // 알림 id 가 없는 푸시의 배너 id 범위 시작 (알림 id 해시와 겹치지 않게 큰 값부터)
  static const _fallbackBannerIdStart = 0x40000000;

  bool _isStarted = false;
  ReadyNavigatorContext? _readyContext;
  final _subscriptions = <StreamSubscription<Object?>>[];

  PendingPushOpen? _pendingOpen;
  String? _lastOpenedKey;
  DateTime? _lastOpenedAt;
  int _nextFallbackBannerId = _fallbackBannerIdStart;

  bool _isRefreshingSummary = false;
  bool _needsSummaryRefreshAgain = false;

  PushMessagingClient get _client => _ref.read(pushMessagingClientProvider);

  LocalNotificationsPlugin get _localNotifications =>
      _ref.read(localNotificationsPluginProvider);

  /// 앱 시작 후 한 번: 전경 수신·누름 구독 + 종료 상태에서 눌러 열린 알림 처리 (두 번째 호출은 무시)
  void start({required ReadyNavigatorContext readyContext}) {
    if (_isStarted) return;
    _isStarted = true;
    _readyContext = readyContext;
    _ref.onDispose(_stop);
    unawaited(_startListening());
  }

  /// 화면이 바뀔 때마다 부름: 기다리던 이동이 있으면 이제 열 수 있는지 확인
  void onRouteChanged() {
    if (_pendingOpen == null) return;
    // 라우터가 알리는 도중에 다시 이동하지 않도록 프레임이 끝난 뒤에 확인
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => unawaited(_openPending()),
    );
  }

  Future<void> _startListening() async {
    try {
      await _localNotifications.ensureInitialized();
      await _localNotifications.createAndroidChannel(_guardianChannel());
    } catch (e, st) {
      // 배너만 못 띄움 (푸시 수신·이동은 계속)
      AppLogger.error('push', e, st, {'step': 'initLocalNotifications'});
    }
    try {
      await _client.disableSystemForegroundPresentation();
      _subscriptions
        ..add(
          _client.onForegroundMessage.listen(
            _onForegroundMessage,
            onError: _onStreamError,
          ),
        )
        ..add(
          _client.onMessageOpenedApp.listen(
            _onMessageOpened,
            onError: _onStreamError,
          ),
        )
        ..add(
          _localNotifications.onNotificationTapped.listen(
            _onLocalNotificationTapped,
          ),
        );
      final initial = await _client.getInitialMessage();
      if (initial != null) _onMessageOpened(initial);
      final launchPayload = await _localNotifications.launchPayload();
      if (launchPayload != null) _onLocalNotificationTapped(launchPayload);
    } catch (e, st) {
      // Firebase 초기화 실패 등: 푸시만 꺼진 채로 앱은 계속
      AppLogger.error('push', e, st, {'step': 'startListening'});
    }
  }

  void _stop() {
    for (final subscription in _subscriptions) {
      unawaited(subscription.cancel());
    }
    _subscriptions.clear();
    _isStarted = false;
  }

  void _onStreamError(Object error, StackTrace stackTrace) =>
      AppLogger.error('push', error, stackTrace, {'step': 'messageStream'});

  AndroidNotificationChannel _guardianChannel() => AndroidNotificationChannel(
    _guardianUpdatesChannelId,
    appL10n.pushChannelGuardianUpdates,
    importance: Importance.high,
  );

  // 로그인한 보호자 기기인가 (이룸이 기기는 보호자 알림을 다루지 않음)
  bool get _isGuardianSignedIn =>
      _ref.read(authSessionControllerProvider).hasSession &&
      !_ref.read(localStorageProvider).isElumiDevice;

  // ----- 전경 수신 -----

  void _onForegroundMessage(PushMessage message) {
    if (!_isGuardianSignedIn) return;
    unawaited(_refreshUnreadSummary());
    // 이룸이 화면을 보여 주는 중에는 배너로 방해하지 않음
    if (_ref.read(localStorageProvider).resumeOnElumiScreen) return;
    unawaited(_showBanner(message));
  }

  // 안 읽음 요약 다시 받기 (연속 수신은 진행 중인 것 끝나고 한 번 더)
  Future<void> _refreshUnreadSummary() async {
    if (_isRefreshingSummary) {
      _needsSummaryRefreshAgain = true;
      return;
    }
    _isRefreshingSummary = true;
    try {
      do {
        _needsSummaryRefreshAgain = false;
        await _ref.read(unreadSummaryProvider.notifier).refresh();
      } while (_needsSummaryRefreshAgain);
    } catch (e, st) {
      AppLogger.error('push', e, st, {'step': 'refreshUnreadSummary'});
    } finally {
      _isRefreshingSummary = false;
    }
  }

  Future<void> _showBanner(PushMessage message) async {
    final title = message.title;
    final body = message.body;
    if (title == null || body == null) return; // 표시할 문구가 없는 data 전용 푸시
    try {
      await _localNotifications.show(
        id: _bannerIdOf(message),
        title: title,
        body: body,
        payload: jsonEncode(message.data),
        channel: _guardianChannel(),
      );
    } catch (e, st) {
      AppLogger.error('push', e, st, {'step': 'showBanner'});
    }
  }

  // 같은 알림은 같은 id 로 (재수신 시 배너가 겹쳐 쌓이지 않음)
  int _bannerIdOf(PushMessage message) {
    final notificationId = message.notificationId;
    if (notificationId != null) return notificationId.hashCode & 0x3fffffff;
    return _nextFallbackBannerId++;
  }

  // ----- 누름 > 이동 -----

  void _onMessageOpened(PushMessage message) => _onTapped(message.data);

  void _onLocalNotificationTapped(String payload) {
    final data = _decodePushPayload(payload);
    // 일과 알림 등 다른 로컬 알림의 payload 는 푸시가 아니라 무시
    if (data == null) return;
    _onTapped(data);
  }

  // 배너 payload(JSON 맵) > data 맵 (푸시 payload 가 아니면 null)
  Map<String, String>? _decodePushPayload(String payload) {
    try {
      final decoded = jsonDecode(payload);
      if (decoded is! Map) return null;
      return {
        for (final entry in decoded.entries)
          if (entry.value != null) entry.key.toString(): entry.value.toString(),
      };
    } on FormatException {
      return null;
    }
  }

  void _onTapped(Map<String, String> data) {
    if (!_isGuardianSignedIn) {
      AppLogger.info('[push] tap dropped : not signed in as guardian');
      return;
    }
    // 종류를 모르거나 없으면 target 이 null > 알림 목록 화면으로
    final open = PendingPushOpen(
      target: NotificationTarget.fromPushData(data),
      notificationId: data['notificationId'],
      tappedAt: DateTime.now(),
    );
    if (_isDuplicateOpen(open)) return;
    _pendingOpen = open;
    unawaited(_openPending());
  }

  bool _isDuplicateOpen(PendingPushOpen open) {
    final key = open.notificationId;
    final lastAt = _lastOpenedAt;
    if (key == null || key != _lastOpenedKey || lastAt == null) return false;
    return open.tappedAt.difference(lastAt) < _duplicateOpenWindow;
  }

  // 기다리는 이동을 열 수 있으면 한 번 열고 비움 (화면이 아직 준비 전이면 둠)
  Future<void> _openPending() async {
    final pending = _pendingOpen;
    if (pending == null) return;
    if (DateTime.now().difference(pending.tappedAt) > _pendingOpenValidity ||
        !_isGuardianSignedIn) {
      AppLogger.info('[push] pending open dropped : expired or signed out');
      _pendingOpen = null;
      return;
    }
    final context = _readyContext?.call();
    if (context == null || !context.mounted) return;

    // 먼저 비워서 겹친 호출이 같은 이동을 두 번 열지 않게 함
    _pendingOpen = null;
    _lastOpenedKey = pending.notificationId;
    _lastOpenedAt = DateTime.now();
    unawaited(_markRead(pending.notificationId));
    final target = pending.target;
    try {
      if (target == null) {
        _openNotificationsScreen(context);
      } else {
        await _ref.read(notificationNavigatorProvider).open(context, target);
      }
    } catch (e, st) {
      AppLogger.error('push', e, st, {'step': 'openFromPush'});
    }
  }

  void _openNotificationsScreen(BuildContext context) {
    final router = GoRouter.of(context);
    final currentPath = router.routerDelegate.currentConfiguration.uri.path;
    if (currentPath == Routes.guardianNotifications) return;
    unawaited(router.push<void>(Routes.guardianNotifications));
  }

  // 눌러 연 알림은 읽음 처리 (실패해도 이동은 그대로, 성공·실패 공통으로 종 아이콘 점 갱신)
  Future<void> _markRead(String? notificationId) async {
    if (notificationId == null) return;
    try {
      await _ref.read(notificationRepositoryProvider).markRead(notificationId);
    } catch (e, st) {
      AppLogger.error('push', e, st, {'step': 'markRead'});
    }
    await _refreshUnreadSummary();
  }
}
