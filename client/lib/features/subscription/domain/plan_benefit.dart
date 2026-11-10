/// 요금제 화면 혜택 줄 — **앱에 실제로 있는 Pro 차이만** 둔다
///
/// 줄마다 여는 권한이 있고(`plan_benefits.dart`), 화면은 서버 Pro 권한에서 켜지고 지금 계정은 못 쓰는 줄만 보인다.
/// 새 Pro 기능 = PlanEntitlements 권한 + 여기 값 하나 + 권한 연결 한 줄 (switch 가 빠뜨림을 막음)
/// 크레딧은 숫자를 적지 않음: 지급량은 관리자 설정이라 Free 계정이 미리 알 수 없음
enum PlanBenefit {
  /// 캐릭터·사진 같은 그림 방식 (AI 맞춤 그림, #1149)
  aiImageStyles,

  /// 광고 없음
  adsRemoved,

  /// 주간 리포트 보기·보내기
  weeklyReport,

  /// 요일·시각 반복 일과, 주간 계획, 이룸이 기기 알림
  routineSchedule,

  /// 이룸이별 AI 메모 (내가 고친 일과처럼 만들기)
  routineMemory,

  /// 카드마다 보호자 목소리
  guardianVoice,

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

  /// 인쇄용 일과 한 장 · 오려 쓰는 카드와 용지 방향 · 장수 · 카드 크기
  cardExportAllLayouts,
}

/// 요금제 화면 혜택 묶음 4개 (#1189 시안 A). 순서 = 화면 순서, [benefits] = 묶음 안 순서
///
/// 새 혜택은 [PlanBenefit] 값 + 여기 한 묶음의 [benefits] 에 한 줄 (빠지면 화면에 안 나옴)
enum PlanBenefitGroup {
  /// 더 예쁜 카드: 그림 · 다시 그리기 · 인쇄
  prettierCards([
    PlanBenefit.aiImageStyles,
    PlanBenefit.freeImageRegenerate,
    PlanBenefit.cardExportAllLayouts,
    PlanBenefit.cardExportAllThemes,
    PlanBenefit.cardExportWithoutWatermark,
  ]),

  /// 일과가 알아서 준비돼요: 반복 · AI 메모
  readyRoutines([
    PlanBenefit.routineSchedule,
    PlanBenefit.routineMemory,
  ]),

  /// 한 주를 한눈에: 주간 리포트 · 보호자 목소리
  weekAtAGlance([PlanBenefit.weeklyReport, PlanBenefit.guardianVoice]),

  /// 넉넉하게, 광고 없이: 크레딧 · 광고
  plentyWithoutAds([
    PlanBenefit.moreWeeklyCredits,
    PlanBenefit.freeRoutineText,
    PlanBenefit.adsRemoved,
  ]);

  const PlanBenefitGroup(this.benefits);

  final List<PlanBenefit> benefits;
}
