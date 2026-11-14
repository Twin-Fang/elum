import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../core/assets/app_assets.dart';
import '../../../core/l10n/l10n_context.dart';
import '../../../core/theme/theme_context_ext.dart';
import '../../../core/widgets/elum_guide_panel.dart';
import '../../../core/widgets/elum_highlight.dart';
import '../../../core/widgets/elum_secondary_button.dart';
import '../../member/application/plan_access.dart';
import '../../subscription/application/credit_pack_catalog.dart';
import '../../subscription/application/plan_paywall_entry.dart';
import '../application/ad_reward_flow.dart';
import 'widgets/credit_top_up_cards.dart';

/// 크레딧 더 받기 시트에서 고른 것 (닫기 · 바깥 누름은 null)
enum CreditTopUpChoice { watchAd, learnPro, seePacks }

/// 크레딧 더 받기 시트 띄우기 > 고른 것 (광고 · Pro · 꾸러미)
Future<CreditTopUpChoice?> showCreditTopUpSheet(
  BuildContext context, {
  required String title,
  required String refillLine,
}) => showElumGuideSheet<CreditTopUpChoice>(
  context: context,
  builder: (_) => CreditTopUpSheet(title: title, refillLine: refillLine),
);

/// 크레딧 더 받기 시트 (안내 뼈대): 루미 그림 > 무슨 일인지 한 줄 > 광고 칸 (주 길) > Pro 칸 > 꾸러미 보조 버튼 > 닫기
///
/// 광고 칸은 미리 불러 둔 광고가 있을 때만 켜짐 (시트가 열리면 불러오기 시작). 광고를 못 보면 칸 대신
/// 이유와 다시 채워지는 때 한 줄. 막다른 시트가 되지 않게 다시 채워지는 때는 늘 어딘가에 보임
/// 칸 보이는 조건: Pro = Free + 요금제 화면을 열 수 있음 · 꾸러미 = 파는 꾸러미가 있음. 채운 버튼은 광고 칸 하나뿐
class CreditTopUpSheet extends ConsumerWidget {
  const CreditTopUpSheet({super.key, required this.title, required this.refillLine});

  final String title;
  final String refillLine;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final space = context.space;
    final l10n = context.l10n;
    final offerState = ref.watch(adRewardOfferStateProvider);
    final isAdCardVisible = offerState.isAdCardVisible;
    final isProCardVisible = !ref.watch(planAccessProvider).isPro && ref.watch(canOpenPlanPaywallProvider);
    final canSeePacks = ref.watch(canPurchaseCreditPacksProvider);
    final unavailableLine = creditTopUpAdUnavailableLine(l10n, offerState);
    void choose(CreditTopUpChoice choice) => Navigator.of(context).pop(choice);

    return ElumGuidePanel(
      placement: ElumGuidePlacement.sheet,
      illustration: const ElumGuideIllustration(
        asset: AppAssets.creditEmptyLumi,
        size: ElumGuideIllustrationSize.sheet,
      ),
      title: title,
      // 광고를 볼 수 있으면 머리에 다시 채워지는 때, 못 보면 아래 이유 줄에 함께
      description: isAdCardVisible ? refillLine : null,
      // 받는 길: 광고 (또는 못 보는 이유와 다시 채워지는 때) > Pro
      content: [
        if (isAdCardVisible)
          CreditTopUpAdCard(offerState: offerState, onWatch: () => choose(CreditTopUpChoice.watchAd))
        else
          ElumHighlight(
            iconAsset: AppAssets.featureIconCalendar,
            tone: ElumHighlightTone.peach,
            text: [?unavailableLine, refillLine].join('\n'),
          ),
        if (isProCardVisible) ...[
          SizedBox(height: space.sm.h),
          CreditTopUpProCard(onTap: () => choose(CreditTopUpChoice.learnPro)),
        ],
      ],
      secondaryActions: [
        if (canSeePacks)
          ElumSecondaryButton(label: l10n.creditTopUpPackLink, onTap: () => choose(CreditTopUpChoice.seePacks)),
        ElumSecondaryButton(label: l10n.commonClose, onTap: () => Navigator.of(context).pop()),
      ],
    );
  }
}
