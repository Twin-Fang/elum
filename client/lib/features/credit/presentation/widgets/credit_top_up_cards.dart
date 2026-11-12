import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../core/assets/app_assets.dart';
import '../../../../core/haptics/tap_haptics.dart';
import '../../../../core/l10n/l10n_context.dart';
import '../../../../core/theme/theme_context_ext.dart';
import '../../../../core/widgets/elum_dialog.dart';
import '../../../../core/widgets/elum_guide_panel.dart';
import '../../../../core/widgets/pro_badge.dart';
import '../../../../core/widgets/pro_upsell_button.dart';
import '../../../member/application/plan_access.dart';
import '../../../subscription/application/plan_paywall_entry.dart';
import '../../../subscription/domain/plan_benefit.dart';
import '../../application/credit_costs.dart';
import '../../domain/ad_reward.dart';

/// 크레딧 시트 칸 공통 면: 흰 카드 + 안쪽 16
class _TopUpCardSurface extends StatelessWidget {
  const _TopUpCardSurface({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final space = context.space;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: context.colors.surface,
        borderRadius: BorderRadius.circular(space.cardRadius.r),
      ),
      child: Padding(
        padding: EdgeInsets.all(space.md.w),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [child]),
      ),
    );
  }
}

/// 광고 칸: 그림 타일 + 제목 > 설명(걸리는 시간 · 오늘 남은 횟수) 또는 못 보는 이유 > `광고 보기`
///
/// 못 볼 때도 칸을 숨기지 않고 버튼만 끔 (왜 안 되는지 보여 줌). 확인 중이면 준비 문구 + 꺼진 버튼
class CreditTopUpAdCard extends StatelessWidget {
  const CreditTopUpAdCard({super.key, required this.availability, required this.onWatch});

  /// 볼 수 있음 · 못 보는 이유 (null 이면 아직 확인 중)
  final AdRewardAvailability? availability;
  final VoidCallback onWatch;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final l10n = context.l10n;
    final offer = availability?.offer;
    final detail = switch (availability?.unavailableReason) {
      _ when offer != null => l10n.creditTopUpAdDetail(offer.remainingToday),
      AdRewardUnavailableReason.switchedOff => l10n.creditTopUpAdOff,
      AdRewardUnavailableReason.dailyLimitReached => l10n.creditTopUpAdDailyLimit,
      AdRewardUnavailableReason.checkFailed => l10n.creditTopUpAdCheckFailed,
      null => l10n.adRewardPreparing,
    };
    return _TopUpCardSurface(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const ElumGuidePictureTile(asset: AppAssets.creditAdRewardLumi),
              SizedBox(width: context.space.sm.w),
              Expanded(
                child: Text(
                  offer == null ? l10n.creditTopUpAdTitleNoCount : l10n.creditTopUpAdTitle(offer.creditsPerView),
                  style: context.typo.creditTitle.copyWith(color: colors.textPrimary),
                ),
              ),
            ],
          ),
          SizedBox(height: context.space.xs.h / 2),
          Text(detail, style: context.typo.creditBody.copyWith(color: colors.textSecondary)),
          SizedBox(height: context.space.sm.h),
          ElumDialogButton(label: l10n.creditTopUpAdWatch, onTap: offer == null ? null : withTapHaptic(onWatch)),
        ],
      ),
    );
  }
}

/// 크레딧이 모자랄 때 보일 Pro 혜택 후보 (앞에서부터 2줄, Pro 가 실제로 주고 지금은 못 쓰는 것만)
const _creditBenefitsInOrder = [
  PlanBenefit.moreWeeklyCredits,
  PlanBenefit.freeRoutineText,
  PlanBenefit.freeImageRegenerate,
];
const _shownBenefitCount = 2;

/// Pro 칸 (Free 일 때만, 부르는 쪽이 판단): PRO 배지 > 크레딧 혜택 2줄 > 테두리 버튼 `7일 무료로 써 보기`
///
/// 혜택 문구는 요금제 화면 줄과 같은 문구 (비교·이득 문구 없음). 누르면 [onTap] (시트가 닫히고 요금제 화면)
class CreditTopUpProCard extends ConsumerWidget {
  const CreditTopUpProCard({super.key, required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final space = context.space;
    final l10n = context.l10n;
    final access = ref.watch(planAccessProvider);
    final periodUnit = ref.watch(creditPeriodUnitProvider);
    final freeRegenerateDailyCap = ref.watch(freeImageRegenerateDailyCapProvider);
    final lines = [
      for (final benefit in _creditBenefitsInOrder)
        if (access.isBenefitOfferedByPro(benefit) && !access.canUseBenefit(benefit))
          switch (benefit) {
            PlanBenefit.freeRoutineText => l10n.planBenefitFreeRoutineText,
            PlanBenefit.freeImageRegenerate =>
              freeRegenerateDailyCap == null
                  ? l10n.planBenefitFreeImageRegenerate
                  : l10n.planBenefitFreeImageRegenerateDaily(freeRegenerateDailyCap),
            _ => periodUnit.planBenefitMoreCredits(l10n),
          },
    ].take(_shownBenefitCount).toList();
    final freeTrialLabel = watchProUpsellActions(context, ref).freeTrialLabel;
    return _TopUpCardSurface(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Align(alignment: Alignment.centerLeft, child: ProBadge()),
          for (final (index, line) in lines.indexed) ...[
            SizedBox(height: (index == 0 ? space.xs : space.xs / 2).h),
            Text(
              line,
              style: index == 0
                  ? context.typo.creditTitle.copyWith(color: colors.textPrimary)
                  : context.typo.creditBody.copyWith(color: colors.textSecondary),
            ),
          ],
          SizedBox(height: space.sm.h),
          ProUpsellButton(style: ProUpsellStyle.outlined, freeTrialLabel: freeTrialLabel, onTap: withTapHaptic(onTap)),
        ],
      ),
    );
  }
}
