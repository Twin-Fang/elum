import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../config/app_config.dart';
import 'app_logger.dart';

/// 크래시·오류 전송 (Firebase Crashlytics): 처리 못 한 오류(치명), 화면이 잡아 보여 준 실패(비치명) (#659)
/// 수집 켜는 조건 2개: 개발자 도구 빌드 + 개발자 도구 스위치 켬. 운영 빌드는 항상 꺼짐
///
/// 보내는 것: 오류 종류(타입 이름), 스택, 에러 코드, 앱 버전·OS·기기 모델(SDK 기본)
/// 보내지 않는 것: 오류 메시지, 입력값·원문, 아이 이름, 토큰, 사용자 식별자(setUserIdentifier 안 부름)
abstract final class CrashReporter {
  // SharedPreferences: 개발자 도구에서 크래시 보내기를 켰는가 (기본 꺼짐)
  // `dev.` 접두사라 로그아웃·회원삭제(LocalStorage.clearAll)가 지우지 않음
  static const _developerOptInKey = 'dev.isCrashReportingEnabled';

  // 비치명 테스트 오류의 에러 코드 (콘솔에서 테스트 건을 거르는 용도)
  static const testErrorCode = 'E-DEV-CRASH-TEST';

  static bool _isEnabled = false;

  /// 지금 Crashlytics 로 보내는 중인가
  static bool get isEnabled => _isEnabled;

  /// 수집을 켤 수 있는 빌드인가 (개발자 도구 빌드만, 운영 빌드는 false)
  static bool get canEnable => AppConfig.showDevTools;

  /// Firebase 초기화 성공 뒤 한 번: 저장한 스위치 값 > 수집 설정 반영 (운영 빌드는 끔)
  static Future<void> applySavedSetting() async {
    await _applyCollection(shouldCollect: await _readDeveloperOptIn());
  }

  /// 개발자 도구 스위치: 저장 > 반영. 반영에 실패하면 false (Firebase 설정 없음 등)
  static Future<bool> setEnabledByDeveloper(bool isEnabledByDeveloper) async {
    if (!canEnable) return false;
    try {
      final preferences = await SharedPreferences.getInstance();
      await preferences.setBool(_developerOptInKey, isEnabledByDeveloper);
    } catch (error, stack) {
      AppLogger.error('crash report', error, stack, {'step': 'saveOptIn'});
    }
    await _applyCollection(shouldCollect: isEnabledByDeveloper);
    return _isEnabled == isEnabledByDeveloper;
  }

  /// 처리 못 한 오류 (FlutterError.onError · PlatformDispatcher.onError)
  static void recordFatal(Object error, StackTrace? stack) =>
      _record(error, stack, isFatal: true);

  /// 화면이 잡아 에러 코드로 보여 준 실패. [errorCode] 로 묶어 본다 (E-AUTH 등)
  static void recordHandled(Object error, StackTrace? stack, {required String errorCode}) =>
      _record(error, stack, isFatal: false, reason: errorCode);

  /// 개발자 도구: 비치명 테스트 오류 1건 (켜져 있을 때만)
  static void sendTestError() => recordHandled(
        StateError('crash report test'),
        StackTrace.current,
        errorCode: testErrorCode,
      );

  /// 개발자 도구: 네이티브 강제 종료 (켜져 있을 때만). 보고서는 다음 실행 때 올라감
  static void sendTestCrash() {
    if (!_isEnabled) return;
    FirebaseCrashlytics.instance.crash();
  }

  // 개발자 도구 빌드에서만 저장값을 읽음 (운영 빌드는 저장값과 무관하게 false)
  static Future<bool> _readDeveloperOptIn() async {
    if (!canEnable) return false;
    try {
      final preferences = await SharedPreferences.getInstance();
      return preferences.getBool(_developerOptInKey) ?? false;
    } catch (error, stack) {
      AppLogger.error('crash report', error, stack, {'step': 'readOptIn'});
      return false;
    }
  }

  // 수집 설정 반영 (네이티브가 값을 기억하므로 꺼짐도 매번 명시)
  // 끌 때는 기기에 쌓인 미전송 보고서도 지움 (꺼진 동안의 크래시가 나중에 켜면 올라가지 않게)
  static Future<void> _applyCollection({required bool shouldCollect}) async {
    try {
      final crashlytics = FirebaseCrashlytics.instance;
      await crashlytics.setCrashlyticsCollectionEnabled(shouldCollect);
      if (!shouldCollect) await crashlytics.deleteUnsentReports();
      _isEnabled = shouldCollect;
    } catch (error, stack) {
      // 전송 도구 실패가 앱 동작을 막지 않음 (수집만 꺼짐)
      _isEnabled = false;
      AppLogger.error('crash report', error, stack, {'step': 'applyCollection'});
    }
  }

  // 메시지 대신 타입 이름만 실어 보낸다 (오류 문구에 사용자 입력·URL·토큰이 섞일 수 있음)
  static void _record(Object error, StackTrace? stack, {required bool isFatal, String? reason}) {
    if (!_isEnabled) return;
    // 전송 실패는 무시 (동기·비동기 둘 다, 로컬 로그에는 이미 남음)
    // 비동기 실패를 놓치면 PlatformDispatcher.onError > recordFatal 로 되돌아옴
    try {
      FirebaseCrashlytics.instance
          .recordError(
            RedactedError(error.runtimeType.toString()),
            stack,
            reason: reason,
            fatal: isFatal,
            printDetails: false,
          )
          .ignore();
    } catch (_) {}
  }
}

/// 원래 오류 대신 보내는 값: 타입 이름만 담는다
@visibleForTesting
class RedactedError {
  const RedactedError(this.errorTypeName);

  final String errorTypeName;

  @override
  String toString() => errorTypeName;
}
