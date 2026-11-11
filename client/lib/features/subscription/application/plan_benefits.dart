import '../../member/domain/plan_entitlements.dart';
import '../domain/plan_benefit.dart';

/// 혜택 줄 > 그 줄을 여는 권한 (크레딧은 켜고 끄는 권한이 아니라 한도라 Pro 여부로 봄)
bool isPlanBenefitGranted(PlanBenefit benefit, PlanEntitlements entitlements) => switch (benefit) {
  PlanBenefit.aiImageStyles => entitlements.canUseAiPictures,
  PlanBenefit.adsRemoved => entitlements.isAdsRemoved,
  PlanBenefit.weeklyReport => entitlements.canViewWeeklyReport,
  PlanBenefit.routineSchedule => entitlements.canScheduleRoutines,
  PlanBenefit.routineMemory => entitlements.canUseRoutineMemory,
  PlanBenefit.cardSplit => entitlements.canSplitCards,
  PlanBenefit.guardianVoice => entitlements.canUseGuardianVoice,
  PlanBenefit.freeRoutineText => entitlements.canCreateRoutineTextFree,
  PlanBenefit.freeImageRegenerate => entitlements.canRegenerateImagesFree,
  PlanBenefit.moreWeeklyCredits => entitlements.isPro,
  PlanBenefit.cardExportWithoutWatermark => entitlements.canExportCardsWithoutWatermark,
  PlanBenefit.cardExportAllThemes => entitlements.canUseAllCardDesignThemes,
  PlanBenefit.cardExportAllLayouts => entitlements.canUseAllCardExportLayouts,
};

/// 요금제 화면 혜택 줄: Pro 요금제가 주고([proPlan]) 지금 계정은 못 쓰는 것만 (순서 = [PlanBenefit] 순서, [highlight] 는 맨 위)
///
/// [proPlan] 은 서버 Pro 권한 설정(`proPlanEntitlements`, #1165) — 관리자가 끈 Pro 권한은 팔지 않음
/// [highlight]: 요금제 화면을 연 기능의 혜택 (예 그림 방식에서 열면 [PlanBenefit.aiImageStyles])
List<PlanBenefit> proPlanBenefits({
  required PlanEntitlements proPlan,
  required PlanEntitlements current,
  PlanBenefit? highlight,
}) {
  final benefits = [
    for (final benefit in PlanBenefit.values)
      if (isPlanBenefitGranted(benefit, proPlan) && !isPlanBenefitGranted(benefit, current)) benefit,
  ];
  if (highlight == null || !benefits.remove(highlight)) return benefits;
  return [highlight, ...benefits];
}

/// 혜택 묶음 하나: 묶음 + 그 안에 보일 혜택 (비지 않음)
typedef PlanBenefitSection = ({PlanBenefitGroup group, List<PlanBenefit> benefits});

/// 요금제 화면 혜택 묶음: [proPlanBenefits] 를 묶음 순서로 나눔. 빈 묶음은 빠짐, [highlight] 의 묶음·혜택은 맨 앞
List<PlanBenefitSection> proPlanBenefitSections({
  required PlanEntitlements proPlan,
  required PlanEntitlements current,
  PlanBenefit? highlight,
}) {
  final shown = proPlanBenefits(proPlan: proPlan, current: current).toSet();
  final sections = <PlanBenefitSection>[];
  for (final group in PlanBenefitGroup.values) {
    final benefits = [
      if (highlight != null && group.benefits.contains(highlight) && shown.contains(highlight)) highlight,
      for (final benefit in group.benefits)
        if (shown.contains(benefit) && benefit != highlight) benefit,
    ];
    if (benefits.isEmpty) continue;
    final section = (group: group, benefits: benefits);
    final isHighlighted = highlight != null && benefits.first == highlight;
    isHighlighted ? sections.insert(0, section) : sections.add(section);
  }
  return sections;
}
