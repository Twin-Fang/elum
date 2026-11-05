/// 요금제 화면 혜택 줄 — **앱에 실제로 있는 Pro 차이만** 둔다
///
/// 줄마다 여는 PlanAccess 판정이 있고(`plan_benefits.dart`), 화면은 Pro 에서 켜지고 Free 에서 꺼진 줄만 보인다.
/// 새 Pro 기능 = PlanAccess 판정 + 여기 값 하나 + 판정 연결 한 줄 (switch 가 빠뜨림을 막음)
/// 크레딧은 숫자를 적지 않음: 지급량은 관리자 설정이라 Free 계정이 미리 알 수 없음
enum PlanBenefit {
  /// 주간 리포트 보기·보내기
  weeklyReport,

  /// 요일·시각 반복 일과, 주간 계획, 이룸이 기기 알림
  routineSchedule,

  /// 이룸이별 AI 메모 (내가 고친 일과처럼 만들기)
  routineMemory,

  /// 전문가 일과 가져오기
  expertRoutines,

  /// 카드마다 보호자 목소리
  guardianVoice,

  /// 만든 일과를 다른 언어 사본으로
  routineTranslate,

  /// 일과 만들기 글 몫 크레딧 없이 (카드 그림은 그대로 듦)
  freeRoutineText,

  /// 카드 그림 다시 그리기 크레딧 없이 (하루 한도까지)
  freeImageRegenerate,

  /// 매주 AI 크레딧 더 많이
  moreWeeklyCredits,

  /// 인쇄용 카드에 로고·워터마크 없음
  cardExportWithoutWatermark,

  /// 인쇄용 카드 디자인 테마 고르기
  cardExportAllThemes,
}
