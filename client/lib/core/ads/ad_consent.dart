import 'dart:io' show Platform;

import 'package:app_tracking_transparency/app_tracking_transparency.dart';

import '../logger/app_logger.dart';

/// 광고를 개인화해서 요청할지 정한다.
///
/// iOS는 추적 권한을 **먼저 물어야** 한다(심사 4.0). 안 물으면 리젝이다.
/// 거부하거나 물을 수 없으면 비개인화로 요청한다 — 앱은 그대로 동작한다.
/// Android는 ATT가 없어 개인화 기본이다.
abstract final class AdConsent {
  /// true면 비개인화 광고로 요청한다.
  static Future<bool> useNonPersonalized() async {
    if (!Platform.isIOS) return false;
    try {
      var status = await AppTrackingTransparency.trackingAuthorizationStatus;
      if (status == TrackingStatus.notDetermined) {
        // 앱이 완전히 활성화되기 전에 요청하면 팝업이 뜨지 않는 경우가 있어 잠깐 기다린다.
        await Future<void>.delayed(const Duration(milliseconds: 500));
        status = await AppTrackingTransparency.requestTrackingAuthorization();
      }
      return status != TrackingStatus.authorized;
    } catch (e, st) {
      // 물을 수 없어도 광고는 비개인화로 진행한다. 조용히 삼키지 않고 남긴다.
      AppLogger.error('ATT 요청 실패', e, st);
      return true;
    }
  }
}
