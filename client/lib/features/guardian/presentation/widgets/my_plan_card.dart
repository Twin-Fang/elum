import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../core/assets/app_assets.dart';
import '../../../../core/l10n/l10n_context.dart';
import '../../../../core/theme/theme_context_ext.dart';
import '../../../../core/widgets/app_pressable.dart';
import '../../../../core/widgets/pro_badge.dart';
import '../../../../core/widgets/pro_member_card.dart';
import '../../../../core/widgets/pro_upsell_button.dart';
import '../../../credit/application/credit_costs.dart';
import '../../../subscription/application/plan_paywall_entry.dart';
import '../../../subscription/application/plan_status_providers.dart';
import '../../../subscription/application/pro_member_benefit_labels.dart';
import '../../../subscription/domain/plan_status.dart';
import 'my_plan_card_parts.dart';

/// 내 정보 맨 위 내 요금제 카드: Pro 는 금빛 회원 카드(칩 > 제목 > 날짜 > 혜택 알약), Free 는 흰 카드(칩 > 제목 > 한 줄 > 권유 버튼)
///
/// Pro 카드 전체는 늘 누름(내 요금제 시트). Free 버튼은 요금제 화면을 열 수 있을 때만, 못 열면 상태만 보임
class MyPlanCard extends ConsumerWidget {
  const MyPlanCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final status = ref.watch(planStatusProvider);
    final canOpenPaywall = ref.watch(canOpenPlanPaywallProvider);
    return status.isPro
        ? _ProPlanFace(status: status)
        : _FreePlanFace(canOpenPaywall: canOpenPaywall);
  }
}

/// Pro 금빛 카드: 누르면 내 요금제 시트 (날짜 · 결제한 곳 · 구독 관리, 판매와 무관, #1303)
class _ProPlanFace extends ConsumerWidget {
  const _ProPlanFace({required this.status});

  final PlanStatus status;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final space = context.space;
    final l10n = context.l10n;
    final title = _proTitleOf(l10n, status);
    // 체험은 제목이 곧 남은 날이라 아래 줄을 겹쳐 쓰지 않음
    final subline = status.isTrial ? null : planStatusFooter(l10n, status);
    final pillLabels = watchProMemberBenefitLabels(context, ref);

    final face = ProMemberCardSurface(
      child: Padding(
        padding: EdgeInsets.all(MyPlanCardLayout.padding.w),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            MyPlanHeader(
              chip: PlanTierChip(tier: planTierOf(status)),
              title: MyPlanTitle(title: title, emojiAsset: _proEmojiOf(status)),
              subline: subline == null
                  ? null
                  : Text(
                      subline,
                      style: context.typo.proPlanTeaserBody.copyWith(color: colors.proPlanMyCardSubText),
                    ),
              mascot: MyPlanMascot.pro(),
            ),
            if (pillLabels.isNotEmpty) ...[
              SizedBox(height: space.md.h),
              Wrap(
                spacing: ProMemberBenefitPill.gap.w,
                runSpacing: ProMemberBenefitPill.gap.h,
                children: [for (final label in pillLabels) ProMemberBenefitPill(label: label)],
              ),
            ],
          ],
        ),
      ),
    );

    final summary = _semanticSummary(l10n, [title, ?subline, ...pillLabels]);
    return AppPressable(
      onTap: () => openMyPlan(context, ref),
      scaleDown: AppPressable.scaleCard,
      semanticLabel: summary,
      child: face,
    );
  }
}

/// Free 흰 카드: 판매 중이면 아래 권유 버튼 (`7일 무료로 써 보기` / `Pro 알아보기`)
class _FreePlanFace extends ConsumerWidget {
  const _FreePlanFace({required this.canOpenPaywall});

  final bool canOpenPaywall;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final space = context.space;
    final l10n = context.l10n;
    final body = ref.watch(creditPeriodUnitProvider).myPlanFreeBody(l10n);
    final title = l10n.myPlanFreeTitle;
    final upsellActions = canOpenPaywall ? watchProUpsellActions(context, ref) : null;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.proPlanMyCardFree,
        borderRadius: BorderRadius.circular(space.cardRadius.r),
      ),
      child: Padding(
        padding: EdgeInsets.all(MyPlanCardLayout.padding.w),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 칩 · 제목 · 한 줄을 한 번에 읽음 (버튼은 따로 누르니 밖에)
            Semantics(
              label: _semanticSummary(l10n, [title, body]),
              excludeSemantics: true,
              child: MyPlanHeader(
                chip: const PlanTierChip(tier: PlanTier.free),
                title: MyPlanTitle(title: title),
                subline: Text(
                  body,
                  style: context.typo.proPlanTeaserBody.copyWith(color: colors.textSecondary),
                ),
                mascot: MyPlanMascot.free(),
              ),
            ),
            if (upsellActions != null) ...[
              SizedBox(height: space.md.h),
              ProUpsellButton(
                style: ProUpsellStyle.filled,
                freeTrialLabel: upsellActions.freeTrialLabel,
                onTap: upsellActions.onStart,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Pro 상태 > 제목: 선물 · 체험(남은 날) · 그 외 Pro
String _proTitleOf(AppLocalizations l10n, PlanStatus status) => switch (status.kind) {
  PlanStatusKind.proGift => l10n.myPlanGiftTitle,
  PlanStatusKind.proTrial => planStatusFooter(l10n, status) ?? l10n.myPlanProTitle,
  _ => l10n.myPlanProTitle,
};

/// Pro 상태 > 제목 끝 이모지: 선물 🎁 · 그 외 🎉
String _proEmojiOf(PlanStatus status) =>
    status.kind == PlanStatusKind.proGift ? AppAssets.myPlanGiftEmoji : AppAssets.myPlanProEmoji;

/// 낭독 문구: `내 요금제` + 카드 글 (쉼표로 이어 한 번에)
String _semanticSummary(AppLocalizations l10n, List<String> parts) =>
    [l10n.planSettingsLabel, ...parts].join(', ');
