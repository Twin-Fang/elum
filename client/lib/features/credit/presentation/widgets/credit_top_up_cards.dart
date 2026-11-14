import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../core/assets/app_assets.dart';
import '../../../../core/haptics/tap_haptics.dart';
import '../../../../core/l10n/l10n_context.dart';
import '../../../../core/theme/theme_context_ext.dart';
import '../../../../core/widgets/elum_dialog.dart';
import '../../../../core/widgets/elum_guide_panel.dart';
import '../../../../core/widgets/kept_text.dart';
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

/// 광고 칸 (주 길): 3D 재생 그림 타일 + 제목 > 걸리는 시간과 받는 크레딧 > 오늘 남은 횟수 > 채운 `광고 보기`
///
/// 미리 불러 둔 광고가 있을 때만 버튼이 켜짐 (누르면 바로 광고). 확인 중 · 불러오는 중이면 준비 문구 + 꺼진 버튼
class CreditTopUpAdCard extends StatelessWidget {
  const CreditTopUpAdCard({super.key, required this.offerState, required this.onWatch});

  final AdRewardOfferState offerState;
  final VoidCallback onWatch;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final space = context.space;
    final l10n = context.l10n;
    final offer = offerState.offer;
    return _TopUpCardSurface(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const ElumGuidePictureTile(asset: AppAssets.featureIconAdPlay),
              SizedBox(width: space.sm.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(l10n.creditTopUpAdTitleNoCount, style: context.typo.creditTitle.copyWith(color: colors.textPrimary)),
                    SizedBox(height: (space.xs / 2).h),
                    KeptText(
                      offer == null ? l10n.adRewardPreparing : l10n.creditTopUpAdDuration(offer.creditsPerView),
                      style: context.typo.creditBody.copyWith(color: colors.textSecondary),
                    ),
                    if (offer != null)
                      Text(
                        l10n.creditTopUpAdRemaining(offer.remainingToday),
                        style: context.typo.creditCaption.copyWith(color: colors.textSecondary),
                      ),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: space.sm.h),
          ElumDialogButton(
            label: offerState.isReady ? l10n.creditTopUpAdWatch : l10n.adRewardPreparing,
            onTap: offerState.isReady ? withTapHaptic(onWatch) : null,
          ),
        ],
      ),
    );
  }
}

/// 광고 칸이 없을 때 이유 한 줄 (못 보는 이유 > null 이면 줄 없음)
String? creditTopUpAdUnavailableLine(AppLocalizations l10n, AdRewardOfferState offerState) =>
    switch (offerState.unavailableReason) {
      AdRewardUnavailableReason.switchedOff => l10n.creditTopUpAdOff,
      AdRewardUnavailableReason.dailyLimitReached => l10n.creditTopUpAdDailyLimit,
      AdRewardUnavailableReason.checkFailed => l10n.creditTopUpAdCheckFailed,
      AdRewardUnavailableReason.noAdLoaded => l10n.creditTopUpAdNoFill,
      null => null,
    };

/// 크레딧이 모자랄 때 보일 Pro 혜택 후보 (앞에서부터 2줄, Pro 가 실제로 주고 지금은 못 쓰는 것만)
const _creditBenefitsInOrder = [
  PlanBenefit.moreWeeklyCredits,
  PlanBenefit.freeRoutineText,
  PlanBenefit.freeImageRegenerate,
];
const _shownBenefitCount = 1;

/// Pro 칸 (Free 일 때만, 부르는 쪽이 판단): PRO 배지 > 크레딧 혜택 한 줄 > 테두리 버튼 `7일 무료로 써 보기`
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
          for (final line in lines) ...[
            SizedBox(height: space.xs.h),
            KeptText(line, style: context.typo.creditTitle.copyWith(color: colors.textPrimary)),
          ],
          SizedBox(height: space.sm.h),
          ProUpsellButton(style: ProUpsellStyle.outlined, freeTrialLabel: freeTrialLabel, onTap: withTapHaptic(onTap)),
        ],
      ),
    );
  }
}
