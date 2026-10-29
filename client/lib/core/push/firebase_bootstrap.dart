import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

import '../analytics/app_analytics.dart';
import '../logger/app_logger.dart';
import '../logger/crash_reporter.dart';

/// 백그라운드·종료 상태 FCM 수신 진입점: 알림형 메시지는 시스템이 직접 띄우므로 처리할 것이 없음
/// 별도 isolate 에서 호출되므로 최상위 함수 + entry-point 표시 필수
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {}

/// Firebase 초기화 > 백그라운드 핸들러 등록 > 크래시·분석 수집 설정 반영(개발자 도구 스위치, 운영은 끔)
/// 설정 파일 누락 등으로 실패해도 앱 시작을 막지 않음 (푸시·크래시·분석 수집만 꺼짐)
Future<void> initializeFirebase() async {
  try {
    await Firebase.initializeApp();
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
    await CrashReporter.applySavedSetting();
    await AppAnalytics.applySavedSetting();
  } catch (error, stackTrace) {
    AppLogger.error('Firebase 초기화', error, stackTrace);
  }
}
