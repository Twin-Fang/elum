import '../../member/application/plan_access.dart';
import '../domain/plan_benefit.dart';

/// 혜택 줄 > 그 줄을 여는 PlanAccess 판정 (크레딧은 켜고 끄는 판정이 아니라 한도라 Pro 여부로 봄)
bool isPlanBenefitGranted(PlanBenefit benefit, PlanAccess access) => switch (benefit) {
  PlanBenefit.aiImageStyles => access.canUseAiPictures,
  PlanBenefit.adsRemoved => access.entitlements.isAdsRemoved,
  PlanBenefit.weeklyReport => access.canViewWeeklyReport,
  PlanBenefit.routineSchedule => access.canScheduleRoutines,
  PlanBenefit.routineMemory => access.canUseRoutineMemory,
  PlanBenefit.expertRoutines => access.canImportExpertRoutines,
  PlanBenefit.guardianVoice => access.canUseGuardianVoice,
  PlanBenefit.routineTranslate => access.canTranslateRoutines,
  PlanBenefit.freeRoutineText => access.canCreateRoutineTextFree,
  PlanBenefit.freeImageRegenerate => access.canRegenerateImagesFree,
  PlanBenefit.moreWeeklyCredits => access.isPro,
  PlanBenefit.cardExportWithoutWatermark => access.canExportCardsWithoutWatermark,
  PlanBenefit.cardExportAllThemes => access.canUseAllCardDesignThemes,
};

/// 요금제 화면 혜택 줄: Pro 판정에서 켜지고 Free 판정에서 꺼진 것만 (순서 = [PlanBenefit] 순서, [highlight] 는 맨 위)
///
/// Free 계정은 Pro 권한을 서버에서 받을 수 없어 앱의 Pro·Free 판정 한 벌([PlanAccess.pro]·[PlanAccess.free])로 견줌
/// [highlight]: 요금제 화면을 연 기능의 혜택 (예 그림 방식에서 열면 [PlanBenefit.aiImageStyles])
List<PlanBenefit> proPlanBenefits({PlanBenefit? highlight}) {
  final benefits = [
    for (final benefit in PlanBenefit.values)
      if (isPlanBenefitGranted(benefit, PlanAccess.pro) && !isPlanBenefitGranted(benefit, PlanAccess.free))
        benefit,
  ];
  if (highlight == null || !benefits.remove(highlight)) return benefits;
  return [highlight, ...benefits];
}
