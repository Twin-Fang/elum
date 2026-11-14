import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../logger/app_logger.dart';
import 'lock_screen_snapshot.dart';

/// 잠금화면 권한 4개: 필수 3개(다른 앱 위에 표시, 알림, 배터리 최적화 제외) + 삼성 기기 여부(절전 예외 권장)
@immutable
class LockScreenPermissionStatus {
  const LockScreenPermissionStatus({
    required this.canDrawOverlays,
    required this.hasNotificationPermission,
    required this.isIgnoringBatteryOptimizations,
    required this.isSamsung,
  });

  static const LockScreenPermissionStatus none = LockScreenPermissionStatus(
    canDrawOverlays: false,
    hasNotificationPermission: false,
    isIgnoringBatteryOptimizations: false,
    isSamsung: false,
  );

  final bool canDrawOverlays;
  final bool hasNotificationPermission;
  final bool isIgnoringBatteryOptimizations;
  final bool isSamsung;

  /// 필수 3개 모두 켜짐 (켜기 판정 기준)
  bool get hasRequiredPermissions =>
      canDrawOverlays &&
      hasNotificationPermission &&
      isIgnoringBatteryOptimizations;

  factory LockScreenPermissionStatus.fromMap(Map<Object?, Object?> map) =>
      LockScreenPermissionStatus(
        canDrawOverlays: map['canDrawOverlays'] == true,
        hasNotificationPermission: map['hasNotificationPermission'] == true,
        isIgnoringBatteryOptimizations:
            map['isIgnoringBatteryOptimizations'] == true,
        isSamsung: map['isSamsung'] == true,
      );
}

/// 잠금화면 설정 (원본은 네이티브 SharedPreferences)
@immutable
class LockScreenSettings {
  const LockScreenSettings({
    required this.isEnabled,
    required this.mode,
    required this.intervalMinutes,
    this.pausedUntil,
  });

  static const LockScreenSettings disabled = LockScreenSettings(
    isEnabled: false,
    mode: LockScreenMode.guardian,
    intervalMinutes: 30,
  );

  final bool isEnabled;
  final LockScreenMode mode;

  /// 마지막 표시 후 최소 간격 (분, 0 = 매번)
  final int intervalMinutes;

  /// 알림 "1시간 쉬기" 끝 시각 (쉬지 않으면 null)
  final DateTime? pausedUntil;

  factory LockScreenSettings.fromMap(Map<Object?, Object?> map) {
    final pauseUntilMillis = map['pauseUntilMillis'];
    return LockScreenSettings(
      isEnabled: map['isEnabled'] == true,
      mode: LockScreenMode.fromWireName(map['mode']),
      intervalMinutes:
          (map['intervalMinutes'] as int?) ?? disabled.intervalMinutes,
      pausedUntil: pauseUntilMillis is int && pauseUntilMillis > 0
          ? DateTime.fromMillisecondsSinceEpoch(pauseUntilMillis)
          : null,
    );
  }
}

/// 소개 시트 노출 기록 (네이티브 저장, Android 전용 기능이라 기기 저장소와 따로 둠)
typedef LockScreenIntroRecord = ({int shownCount, DateTime? lastShownAt});

/// 네이티브 잠금화면 채널(elum/lock_screen) 래퍼: Android 전용, 그 외 플랫폼은 아무것도 하지 않음
/// 네이티브 > Dart 신호 2개: 잠금화면 표시(잠금 엔진), 이동 경로(앱 엔진)
class LockScreenBridge {
  LockScreenBridge({MethodChannel? channel, bool? isSupported})
    : _channel = channel ?? const MethodChannel(_channelName),
      isLockScreenSupported =
          isSupported ??
          (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
    if (isLockScreenSupported) _channel.setMethodCallHandler(_onNativeCall);
  }

  static const String _channelName = 'elum/lock_screen';

  final MethodChannel _channel;

  /// 잠금화면 기능을 쓸 수 있는 플랫폼 (Android)
  final bool isLockScreenSupported;

  final StreamController<void> _shownController =
      StreamController<void>.broadcast();
  final StreamController<String> _routeController =
      StreamController<String>.broadcast();

  /// 마지막으로 보낸 요약 (같은 값이면 다시 보내지 않음, 로그아웃 정리가 비움)
  static String? _lastPushedSnapshotJson;

  /// 잠금화면이 새로 보임 (잠금 엔진만)
  Stream<void> get shownSignals => _shownController.stream;

  /// 잠금화면·알림에서 앱을 연 경로 (앱이 이미 떠 있을 때)
  Stream<String> get openedRoutes => _routeController.stream;

  Future<dynamic> _onNativeCall(MethodCall call) async {
    switch (call.method) {
      case 'onShown':
        _shownController.add(null);
      case 'openRoute':
        final route = call.arguments;
        if (route is String) _routeController.add(route);
    }
  }

  Future<LockScreenPermissionStatus> getPermissionStatus() async {
    final map = await _invoke<Map<Object?, Object?>>('getPermissionStatus');
    return map == null
        ? LockScreenPermissionStatus.none
        : LockScreenPermissionStatus.fromMap(map);
  }

  Future<LockScreenSettings> getSettings() async {
    final map = await _invoke<Map<Object?, Object?>>('getSettings');
    return map == null
        ? LockScreenSettings.disabled
        : LockScreenSettings.fromMap(map);
  }

  Future<void> openOverlaySettings() => _invoke<void>('openOverlaySettings');
  Future<void> openNotificationSettings() =>
      _invoke<void>('openNotificationSettings');
  Future<void> openBatteryOptimizationSettings() =>
      _invoke<void>('openBatteryOptimizationSettings');
  Future<void> openSamsungPowerSettings() =>
      _invoke<void>('openSamsungPowerSettings');

  /// 켜기 (쉬는 중이면 쉬기도 해제): 필수 권한 3개가 없으면 네이티브가 거부 > false
  Future<bool> enable({
    required LockScreenMode mode,
    required int intervalMinutes,
  }) async =>
      await _invoke<bool>('enable', {
        'mode': mode.wireName,
        'intervalMinutes': intervalMinutes,
      }) ??
      false;

  Future<void> disable() => _invoke<void>('disable');

  Future<void> updateInterval(int intervalMinutes) =>
      _invoke<void>('updateSettings', {'intervalMinutes': intervalMinutes});

  /// 오늘 일과 요약 저장 (같은 값이면 건너뜀, null 이면 지움 · 로그아웃)
  Future<void> updateSnapshot(LockScreenSnapshot? snapshot) async {
    final json = snapshot?.toJsonString();
    if (json == _lastPushedSnapshotJson) return;
    _lastPushedSnapshotJson = json;
    await _invoke<void>('updateSnapshot', {'json': json});
  }

  /// 저장된 요약 (잠금 엔진이 보일 때마다 읽음, 없거나 깨졌으면 null)
  Future<LockScreenSnapshot?> readSnapshot() async =>
      LockScreenSnapshot.tryParse(await _invoke<String>('getSnapshot'));

  /// 잠금화면 "1시간 쉬기": 쉬기 시작 > 잠금화면 닫기
  Future<void> pauseOneHour() => _invoke<void>('pauseOneHour');

  Future<LockScreenIntroRecord> readIntroRecord() async {
    final map = await _invoke<Map<Object?, Object?>>('getIntroRecord');
    final lastShownAtMillis = map?['lastShownAtMillis'];
    return (
      shownCount: (map?['shownCount'] as int?) ?? 0,
      lastShownAt: lastShownAtMillis is int && lastShownAtMillis > 0
          ? DateTime.fromMillisecondsSinceEpoch(lastShownAtMillis)
          : null,
    );
  }

  Future<void> recordIntroShown() => _invoke<void>('recordIntroShown');

  /// Dart 준비 전에 온 표시 요청 (잠금 엔진 시작 때 1회)
  Future<bool> consumePendingShow() async =>
      await _invoke<bool>('consumePendingShow') ?? false;

  /// 앱이 꺼진 상태에서 열린 경로 (앱 엔진 시작 때 1회)
  Future<String?> takePendingRoute() => _invoke<String>('takePendingRoute');

  /// 잠금화면 닫기 (잠금은 그대로)
  Future<void> dismiss() => _invoke<void>('dismiss');

  /// 잠금 해제 후 앱에서 [route] 열기
  Future<void> unlockAndOpen(String route) =>
      _invoke<void>('unlockAndOpen', {'route': route});

  /// 채널 호출 (미지원 플랫폼 null, 채널 오류는 로그만 남기고 null)
  Future<T?> _invoke<T>(
    String method, [
    Map<String, Object?>? arguments,
  ]) async {
    if (!isLockScreenSupported) return null;
    try {
      return await _channel.invokeMethod<T>(method, arguments);
    } on PlatformException catch (error) {
      AppLogger.error('lock screen', '$method failed : ${error.code}');
      return null;
    } on MissingPluginException {
      return null;
    }
  }
}

/// 로그아웃·탈퇴: 잠금화면 카드 끄기 + 요약 지우기 (일과 제목이 남지 않게, 실패해도 계속)
/// 채널 처리기를 바꾸지 않으려고 인스턴스 없이 직접 부름
Future<void> clearLockScreenForSignOut() async {
  if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return;
  LockScreenBridge._lastPushedSnapshotJson = null;
  const channel = MethodChannel(LockScreenBridge._channelName);
  try {
    await channel.invokeMethod<void>('disable');
    await channel.invokeMethod<void>('updateSnapshot', {'json': null});
  } on PlatformException catch (error) {
    AppLogger.error('lock screen', 'sign out clear failed : ${error.code}');
  } on MissingPluginException {
    // 테스트·지원하지 않는 기기
  }
}

/// 앱 전역 잠금화면 채널
final lockScreenBridgeProvider = Provider<LockScreenBridge>(
  (ref) => LockScreenBridge(),
);
