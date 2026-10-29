/// 분석 이벤트 이름 원본 (#650). Firebase 규칙: 영문 snake_case, 40자 이내
/// 각 이벤트가 답하는 질문은 이슈 #650 이벤트 표
abstract final class AnalyticsEvents {
  /// 새 보호자가 비밀암호까지 마쳐 홈으로 감
  static const onboardingComplete = 'onboarding_complete';

  /// 카드 생성 요청 (AI 호출 1회)
  static const routineGenerateStart = 'routine_generate_start';
  static const routineGenerateComplete = 'routine_generate_complete';

  /// 생성 실패·시간 초과 (에러 코드만)
  static const routineGenerateFail = 'routine_generate_fail';

  /// 카드확인 `저장하기` > 승인 성공 (이룸이 화면에 나감)
  static const routineConfirm = 'routine_confirm';

  /// 이룸이가 일과의 마지막 카드를 처음 체크
  static const childRoutineComplete = 'child_routine_complete';

  /// 일과 만들기 전 크레딧 안내 팝업이 막음
  static const creditBlocked = 'credit_blocked';

  /// 의견 보내기 결과 (성공·실패 공통)
  static const feedbackSend = 'feedback_send';

  /// 개발자 도구 테스트 이벤트 (콘솔 DebugView 확인용)
  static const developerTest = 'dev_test_event';
}

/// 분석 파라미터 키 원본 (#650). 값은 숫자·코드만 (원문·이름·토큰·식별자 금지, 서비스 원칙 1·5)
abstract final class AnalyticsParameters {
  /// 화면 경로 패턴 (`/guardian/talk/posts/:postId`, id·쿼리 없음)
  static const screenName = 'screen_name';

  /// 서버 저장까지 됐는가: 1 예, 0 아니오
  static const isServerSaved = 'is_server_saved';

  /// 온보딩에서 고른 예시 일과 분류 개수
  static const exampleCategoryCount = 'example_category_count';

  /// 일과의 카드 수
  static const cardCount = 'card_count';

  /// 화면 배지와 같은 에러 코드 (`E-1001/500`, `CREDIT_INSUFFICIENT` 등)
  static const errorCode = 'error_code';

  /// 크레딧 안내 사유: [creditBlockedExhausted], [creditBlockedGenerating]
  static const reason = 'reason';
  static const creditBlockedExhausted = 'exhausted';
  static const creditBlockedGenerating = 'generating';

  /// 의견 보내기 성공: 1 예, 0 아니오
  static const isSent = 'is_sent';

  /// 앱 상태 기록을 붙였는가: 1 예, 0 아니오
  static const hasAppLog = 'has_app_log';
}
