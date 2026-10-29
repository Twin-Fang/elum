import 'package:firebase_analytics/firebase_analytics.dart';

import '../config/developer_collection_opt_in.dart';
import '../logger/app_logger.dart';
import 'analytics_events.dart';

/// 사용자 행동 분석 전송 (Firebase Analytics): 화면 추적, 핵심 이벤트 (#650)
/// 수집 켜는 조건 2개: 개발자 도구 빌드 + 개발자 도구 스위치 켬. 운영 빌드는 항상 꺼짐
///
/// 보내는 것: 화면 경로 패턴, 이벤트 이름, 숫자·에러 코드 파라미터, SDK 기본(앱 버전·OS·기기 모델·무작위 앱 인스턴스 id)
/// 보내지 않는 것: 진단명·장애 유형, 원문(카드 글·일과 제목), 아이 이름, 토큰, 사용자 id(setUserId 안 부름), 광고 식별자(네이티브 설정으로 끔)
abstract final class AppAnalytics {
  // 실패 로그 분류 (스위치 저장·수집 반영 공통)
  static const _logCategory = 'analytics';

  // 개발자 도구 스위치: 분석 보내기를 켰는가 (기본 꺼짐)
  static const _developerOptIn = DeveloperCollectionOptIn(
    storageKey: 'dev.isAnalyticsEnabled',
    logCategory: _logCategory,
  );

  static bool _isEnabled = false;

  /// 지금 Firebase Analytics 로 보내는 중인가
  static bool get isEnabled => _isEnabled;

  /// 수집을 켤 수 있는 빌드인가 (개발자 도구 빌드만, 운영 빌드는 false)
  static bool get canEnable => DeveloperCollectionOptIn.canEnable;

  /// Firebase 초기화 성공 뒤 한 번: 저장한 스위치 값 > 수집 설정 반영 (운영 빌드는 끔)
  static Future<void> applySavedSetting() async {
    await _applyCollection(shouldCollect: await _developerOptIn.readIsOptedIn());
  }

  /// 개발자 도구 스위치: 저장 > 반영 (끌 때는 기기의 분석 데이터·앱 인스턴스 id 초기화)
  /// 반영에 실패하면 false (Firebase 설정 없음 등)
  static Future<bool> setEnabledByDeveloper(bool isEnabledByDeveloper) async {
    if (!canEnable) return false;
    await _developerOptIn.saveIsOptedIn(isEnabledByDeveloper);
    await _applyCollection(shouldCollect: isEnabledByDeveloper);
    if (!isEnabledByDeveloper) await _resetCollectedData();
    return _isEnabled == isEnabledByDeveloper;
  }

  /// 화면 이동 (라우터 한 곳에서만 부름, AnalyticsScreenTracker)
  static void logScreenView(String routePattern) {
    if (!_isEnabled) return;
    _send(() => FirebaseAnalytics.instance.logScreenView(
          screenName: routePattern,
          screenClass: routePattern,
        ));
  }

  static void logOnboardingCompleted({
    required bool isServerSaved,
    required int exampleCategoryCount,
  }) =>
      _logEvent(AnalyticsEvents.onboardingComplete, {
        AnalyticsParameters.isServerSaved: _toFlag(isServerSaved),
        AnalyticsParameters.exampleCategoryCount: exampleCategoryCount,
      });

  static void logRoutineGenerationStarted() =>
      _logEvent(AnalyticsEvents.routineGenerateStart);

  static void logRoutineGenerationCompleted({required int cardCount}) =>
      _logEvent(AnalyticsEvents.routineGenerateComplete, {
        AnalyticsParameters.cardCount: cardCount,
      });

  static void logRoutineGenerationFailed({required String errorCode}) =>
      _logEvent(AnalyticsEvents.routineGenerateFail, {
        AnalyticsParameters.errorCode: errorCode,
      });

  static void logRoutineConfirmed({required int cardCount}) =>
      _logEvent(AnalyticsEvents.routineConfirm, {
        AnalyticsParameters.cardCount: cardCount,
      });

  static void logChildRoutineCompleted({required int cardCount}) =>
      _logEvent(AnalyticsEvents.childRoutineComplete, {
        AnalyticsParameters.cardCount: cardCount,
      });

  static void logCreditBlocked({required bool isGeneratingRoutine}) =>
      _logEvent(AnalyticsEvents.creditBlocked, {
        AnalyticsParameters.creditBlockedReason: isGeneratingRoutine
            ? AnalyticsParameters.creditBlockedGenerating
            : AnalyticsParameters.creditBlockedExhausted,
      });

  /// 실패면 [errorCode] 를 함께 (성공은 null)
  static void logFeedbackSent({
    required bool isSent,
    required bool hasAppLog,
    String? errorCode,
  }) =>
      _logEvent(AnalyticsEvents.feedbackSend, {
        AnalyticsParameters.isSent: _toFlag(isSent),
        AnalyticsParameters.hasAppLog: _toFlag(hasAppLog),
        AnalyticsParameters.errorCode: ?errorCode,
      });

  /// 개발자 도구: 테스트 이벤트 1건 (켜져 있을 때만)
  static void sendTestEvent() => _logEvent(AnalyticsEvents.developerTest);

  // 수집 설정 반영 (네이티브가 값을 기억하므로 꺼짐도 매번 명시)
  static Future<void> _applyCollection({required bool shouldCollect}) async {
    try {
      await FirebaseAnalytics.instance.setAnalyticsCollectionEnabled(shouldCollect);
      _isEnabled = shouldCollect;
    } catch (error, stack) {
      // 전송 도구 실패가 앱 동작을 막지 않음 (수집만 꺼짐)
      _isEnabled = false;
      AppLogger.error(_logCategory, error, stack, {'step': 'applyCollection'});
    }
  }

  // 꺼진 뒤 다시 켜도 이전 앱 인스턴스 id 로 이어 붙지 않게
  static Future<void> _resetCollectedData() async {
    try {
      await FirebaseAnalytics.instance.resetAnalyticsData();
    } catch (error, stack) {
      AppLogger.error(_logCategory, error, stack, {'step': 'resetData'});
    }
  }

  static void _logEvent(String eventName, [Map<String, Object>? parameters]) {
    if (!_isEnabled) return;
    _send(() => FirebaseAnalytics.instance.logEvent(
          name: eventName,
          parameters: parameters,
        ));
  }

  // 전송 실패는 무시 (동기·비동기 둘 다). 비동기 실패를 놓치면 PlatformDispatcher.onError 로 감
  static void _send(Future<void> Function() sendToFirebase) {
    try {
      sendToFirebase().ignore();
    } catch (_) {}
  }

  // Firebase 파라미터는 bool 을 받지 않아 1·0 으로
  static int _toFlag(bool isSet) => isSet ? 1 : 0;
}
