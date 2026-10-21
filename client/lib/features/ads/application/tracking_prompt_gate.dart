import '../data/ad_consent.dart';

/// 앱 시작 때 뜨는 추적 허용 팝업(iOS ATT)이 끝날 때까지 기다린다
///
/// 코치마크처럼 화면 전체를 덮는 안내가 이 팝업과 겹치면 팝업에 가려 보이지 않는다. 이미 답했거나
/// Android 면 바로 끝난다. 실패해도 예외 없이 끝난다 (실패는 [AdConsent] 가 남긴다).
Future<void> waitForTrackingPrompt() => AdConsent.requestOnLaunch();
