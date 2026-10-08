import 'dart:async';
import 'dart:io' show Platform;

import 'package:app_tracking_transparency/app_tracking_transparency.dart';
import 'package:flutter/widgets.dart';

import '../../../core/logger/app_logger.dart';

/// 광고를 개인화해서 요청할지 정한다.
///
/// iOS는 추적 권한을 **먼저 물어야** 한다(심사 4.0). 안 물으면 리젝이다.
/// 거부하거나 물을 수 없으면 비개인화로 요청한다 — 앱은 그대로 동작한다.
/// Android는 ATT가 없어 개인화 기본이다.
///
/// 팝업은 광고 요청이 아니라 **앱 시작 직후** [requestOnLaunch] 가 띄운다. 광고 요청에
/// 묶어 두면 광고가 안 뜨는 경로(로그인 전·요금제 조회 중·광고 제거 요금제)로 쓰는 심사관은
/// 팝업을 한 번도 못 본다(#519 심사 2.1 리젝). 광고 로더의 [useNonPersonalized] 는 이미
/// 받은 답을 읽고, 아직 못 받았으면 안전망으로 한 번 더 묻는다.
abstract final class AdConsent {
  /// 앱이 활성화된 뒤 팝업이 뜨기까지 두는 짧은 여유.
  static const _settle = Duration(milliseconds: 500);

  /// 앱이 활성화되기를 기다리는 최대 시간. 넘기면 그대로 요청한다.
  static const _activeTimeout = Duration(seconds: 10);

  // 시작 요청과 광고 로더가 동시에 부르면 팝업이 두 번 요청되므로 진행 중인 요청을 공유한다.
  static Future<TrackingStatus?>? _inFlight;

  @visibleForTesting
  static bool Function() isIos = () => Platform.isIOS;

  @visibleForTesting
  static Future<TrackingStatus> Function() readStatus = () =>
      AppTrackingTransparency.trackingAuthorizationStatus;

  @visibleForTesting
  static Future<TrackingStatus> Function() requestAuthorization = () =>
      AppTrackingTransparency.requestTrackingAuthorization();

  @visibleForTesting
  static Future<void> Function() waitUntilActive = _waitUntilResumed;

  @visibleForTesting
  static Duration settle = _settle;

  @visibleForTesting
  static void resetForTest() {
    _inFlight = null;
    isIos = () => Platform.isIOS;
    readStatus = () => AppTrackingTransparency.trackingAuthorizationStatus;
    requestAuthorization = () =>
        AppTrackingTransparency.requestTrackingAuthorization();
    waitUntilActive = _waitUntilResumed;
    settle = _settle;
  }

  /// 앱을 열자마자 추적 허용을 한 번 묻는다. 이미 답한 휴대폰에서는 묻지 않는다.
  ///
  /// 실패해도 앱은 계속 진행한다 — 실패는 [AppLogger] 에 남기고 광고는 비개인화로 간다.
  static Future<void> requestOnLaunch() async {
    await _resolve();
  }

  /// true면 비개인화 광고로 요청한다.
  static Future<bool> useNonPersonalized() async {
    if (!isIos()) return false;
    final status = await _resolve();
    // 상태를 못 얻으면(null) 개인화로 요청하지 않는다.
    return status != TrackingStatus.authorized;
  }

  static Future<TrackingStatus?> _resolve() {
    if (!isIos()) return Future.value();
    return _inFlight ??= _ask().whenComplete(() {
      // 답을 받았으면 다시 묻지 않고, 실패했으면 다음 요청에서 다시 시도할 수 있게 비운다.
      _inFlight = null;
    });
  }

  static Future<TrackingStatus?> _ask() async {
    try {
      var status = await readStatus();
      if (status == TrackingStatus.notDetermined) {
        // 앱이 완전히 활성화되기 전에 요청하면 iOS가 팝업을 조용히 무시한다.
        await waitUntilActive();
        await Future<void>.delayed(settle);
        status = await requestAuthorization();
      }
      return status;
    } catch (e, st) {
      // 물을 수 없어도 광고는 비개인화로 진행한다. 조용히 삼키지 않고 남긴다.
      AppLogger.error('ATT 요청 실패', e, st);
      return null;
    }
  }

  static Future<void> _waitUntilResumed() async {
    final state = WidgetsBinding.instance.lifecycleState;
    // 아직 상태를 모르는 첫 프레임 직후(null)는 활성으로 본다.
    if (state == null || state == AppLifecycleState.resumed) return;
    final done = Completer<void>();
    final listener = AppLifecycleListener(
      onResume: () {
        if (!done.isCompleted) done.complete();
      },
    );
    try {
      await done.future.timeout(_activeTimeout, onTimeout: () {});
    } finally {
      listener.dispose();
    }
  }
}
