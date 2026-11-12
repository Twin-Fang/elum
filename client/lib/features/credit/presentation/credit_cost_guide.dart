import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/assets/app_assets.dart';
import '../../../core/haptics/tap_haptics.dart';
import '../../../core/l10n/l10n_context.dart';
import '../../../core/widgets/elum_guide_panel.dart';
import '../../../core/widgets/pro_badge.dart';
import '../../../core/widgets/pro_upsell_button.dart';
import '../../member/application/plan_access.dart';
import '../../subscription/application/plan_status_providers.dart';
import '../../subscription/domain/plan_benefit.dart';
import '../domain/credit_summary.dart';

/// 크레딧 안내 창에서 고른 것 (알겠어요 · 바깥은 null)
enum CreditCostGuideChoice { learnPro }

/// 크레딧 안내 창: 그림 > 제목 > 요금제 칩 > 표 4줄 > 설명 2줄 > (Free) Pro 사실 한 줄 + `Pro 알아보기` > `알겠어요`
/// 값은 서버 단가 · 지급량 · 요금제 권한으로 계산 (글 무료 권한 `제한 없음`, 다시 그리기 무료 권한 `하루 N번 무료`)
class CreditCostGuide extends ConsumerWidget {
  const CreditCostGuide({super.key, required this.summary});

  final CreditSummary summary;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final access = ref.watch(planAccessProvider);
    final tier = planTierOf(ref.watch(planStatusProvider));
    final periodUnit = summary.periodUnit;
    final proFact = access.isPro ? null : _proFact(l10n, access);
    return ElumGuidePanel(
      placement: ElumGuidePlacement.dialog,
      illustration: const ElumGuideIllustration(asset: AppAssets.creditTicket, size: ElumGuideIllustrationSize.dialog),
      title: l10n.creditGuideTitle,
      titleAccessory: PlanTierChip(tier: tier),
      description: l10n.creditGuideBasis,
      content: [
        // 표: 쓰는 곳 3줄 + 주기 지급량
        ElumGuideRow(
          iconAsset: AppAssets.iconPencil,
          label: l10n.creditGuideRoutineText,
          value: access.canCreateRoutineTextFree ? l10n.creditGuideUnlimited : l10n.creditGuideCount(summary.routineTextCost),
        ),
        ElumGuideRow(
          iconAsset: AppAssets.iconPicture,
          label: l10n.creditGuideCardImage,
          value: l10n.creditGuideCount(summary.cardImageCost),
        ),
        ElumGuideRow(
          iconAsset: AppAssets.iconRefresh,
          label: l10n.creditGuideRegenerate,
          value: _regenerateValue(l10n, access),
        ),
        ElumGuideRow(
          iconAsset: AppAssets.iconCoins,
          label: periodUnit.isMonth ? l10n.creditGuideMonthlyGrant : l10n.creditGuideWeeklyGrant,
          value: l10n.creditGuideCount(summary.weeklyGrant),
        ),
        const ElumGuideDivider(),
        // 설명 줄: 끝까지 만들어짐 · 다시 채워지는 때
        ElumGuideNote(iconAsset: AppAssets.iconCheck, text: l10n.creditGuideKeepGoing),
        ElumGuideNote(
          iconAsset: AppAssets.iconCalendar,
          text: periodUnit.isMonth ? l10n.creditGuideRefillMonth : l10n.creditGuideRefillWeek,
        ),
        // Free: Pro 사실 한 줄 (Pro 가 실제로 주는 것만, 비교 없음)
        if (proFact != null) ...[const ElumGuideDivider(), ElumGuideNote(text: proFact)],
      ],
      primaryAction: ElumGuideAction(label: l10n.creditGuideConfirm, onTap: () => Navigator.of(context).pop()),
      secondaryActions: [
        if (access.shouldShowProTeaser)
          ProUpsellButton(
            style: ProUpsellStyle.link,
            onTap: withTapHaptic(() => Navigator.of(context).pop(CreditCostGuideChoice.learnPro)),
          ),
      ],
    );
  }

  /// 다시 그리기 값: 무료 권한 > `하루 N번 무료` (한도를 모르는 이전 서버면 오늘 남은 횟수), 아니면 단가
  String _regenerateValue(AppLocalizations l10n, PlanAccess access) {
    if (!access.canRegenerateImagesFree) return l10n.creditGuideCount(summary.imageRegenerateCost);
    final dailyCap = summary.freeImageRegenerateDailyCap;
    return dailyCap > 0
        ? l10n.creditGuideRegenerateFreeDaily(dailyCap)
        : l10n.creditGuideRegenerateFreeToday(summary.freeImageRegeneratesLeftToday);
  }

  /// Free 에게 보이는 Pro 사실: Pro 가 주는 글 무료 · 다시 그리기 무료 조합 (하루 한도를 모르면 다시 그리기는 뺌)
  String? _proFact(AppLocalizations l10n, PlanAccess access) {
    final isTextFreeOffered = access.isBenefitOfferedByPro(PlanBenefit.freeRoutineText);
    final dailyCap = summary.freeImageRegenerateDailyCap;
    final isRegenerateFreeOffered = access.isBenefitOfferedByPro(PlanBenefit.freeImageRegenerate) && dailyCap > 0;
    return switch ((isTextFreeOffered, isRegenerateFreeOffered)) {
      (true, true) => l10n.creditGuideProFactBoth(dailyCap),
      (true, false) => l10n.creditGuideProFactText,
      (false, true) => l10n.creditGuideProFactRegenerate(dailyCap),
      (false, false) => null,
    };
  }
}
