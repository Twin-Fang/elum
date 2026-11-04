/// 요금제 화면 혜택 줄 3개 — **앱에 실제로 있는 Pro 차이만** 둔다
///
/// 새 Pro 기능이 앱에 들어오면 여기에 값을 더한다 (주간 리포트·반복 일과 등은 생길 때)
/// 크레딧은 숫자를 적지 않음: Pro 지급량은 관리자 설정이라 Free 계정이 미리 알 수 없음
enum PlanBenefit {
  /// 매주 AI 크레딧 더 많이
  moreWeeklyCredits,

  /// 인쇄용 카드에 로고·워터마크 없음
  cardExportWithoutWatermark,

  /// 인쇄용 카드 디자인 테마 고르기
  cardExportAllThemes,
}
