import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';

import '../config/app_config.dart';

/// 크래시·오류 전송 (Firebase Crashlytics): 처리 못 한 오류(치명), 화면이 잡아 보여 준 실패(비치명)
/// 보내는 것 4개: 오류 종류(타입 이름), 스택, 앱 버전, OS (메시지·입력값·사용자 식별자는 보내지 않음)
abstract final class CrashReporter {
  static bool _isEnabled = false;

  /// Firebase 초기화 성공 뒤 한 번. 릴리스 빌드이고 개발자 도구가 꺼져 있을 때만 켠다
  static Future<void> enableIfAllowed() async {
    final shouldCollect = kReleaseMode && !AppConfig.showDevTools;
    try {
      await FirebaseCrashlytics.instance.setCrashlyticsCollectionEnabled(shouldCollect);
      _isEnabled = shouldCollect;
    } catch (_) {
      // 전송 도구 실패가 앱 동작을 막지 않음 (수집만 꺼짐)
      _isEnabled = false;
    }
  }

  /// 처리 못 한 오류 (FlutterError.onError · PlatformDispatcher.onError)
  static void recordFatal(Object error, StackTrace? stack) =>
      _record(error, stack, isFatal: true);

  /// 화면이 잡아 에러 코드로 보여 준 실패. [errorCode] 로 묶어 본다 (E-AUTH 등)
  static void recordHandled(Object error, StackTrace? stack, {required String errorCode}) =>
      _record(error, stack, isFatal: false, reason: errorCode);

  // 메시지 대신 타입 이름만 실어 보낸다 (오류 문구에 사용자 입력·URL 이 섞일 수 있음)
  static void _record(Object error, StackTrace? stack, {required bool isFatal, String? reason}) {
    if (!_isEnabled) return;
    try {
      FirebaseCrashlytics.instance.recordError(
        RedactedError(error.runtimeType.toString()),
        stack,
        reason: reason,
        fatal: isFatal,
        printDetails: false,
      );
    } catch (_) {
      // 전송 실패는 무시 (앱 동작 영향 없음, 로컬 로그에는 이미 남음)
    }
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
