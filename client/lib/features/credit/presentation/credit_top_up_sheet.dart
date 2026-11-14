import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../core/assets/app_assets.dart';
import '../../../core/l10n/l10n_context.dart';
import '../../../core/theme/theme_context_ext.dart';
import '../../../core/widgets/elum_guide_panel.dart';
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

/// 크레딧 더 받기 시트 (안내 뼈대): 루미 그림 > 제목 > 다시 채워지는 때 > 광고 칸 > Pro 칸 > 꾸러미 글자 버튼 > 닫기
///
/// 칸 보이는 조건 3개: 광고 = 이 기기가 광고를 띄울 수 있음 (못 볼 땐 꺼진 버튼 + 이유) ·
/// Pro = Free + 요금제 화면을 열 수 있음 · 꾸러미 = 파는 꾸러미가 있음. 채운 버튼은 광고 칸 하나뿐
class CreditTopUpSheet extends ConsumerWidget {
  const CreditTopUpSheet({super.key, required this.title, required this.refillLine});

  final String title;
  final String refillLine;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final space = context.space;
    final l10n = context.l10n;
    final availability = ref.watch(adRewardAvailabilityProvider);
    // 확인이 끝났는데 null > 이 기기는 광고를 못 띄움 (광고 없는 요금제 등) > 칸 숨김
    final isAdCardVisible = !availability.hasValue || availability.value != null;
    final isProCardVisible = !ref.watch(planAccessProvider).isPro && ref.watch(canOpenPlanPaywallProvider);
    final canSeePacks = ref.watch(canPurchaseCreditPacksProvider);
    void choose(CreditTopUpChoice choice) => Navigator.of(context).pop(choice);

    return ElumGuidePanel(
      placement: ElumGuidePlacement.sheet,
      illustration: const ElumGuideIllustration(
        asset: AppAssets.creditEmptyLumi,
        size: ElumGuideIllustrationSize.sheet,
      ),
      title: title,
      description: refillLine,
      // 받는 길: 광고 > Pro
      content: [
        if (isAdCardVisible)
          CreditTopUpAdCard(
            availability: availability.value,
            onWatch: () => choose(CreditTopUpChoice.watchAd),
          ),
        if (isAdCardVisible && isProCardVisible) SizedBox(height: space.sm.h),
        if (isProCardVisible) CreditTopUpProCard(onTap: () => choose(CreditTopUpChoice.learnPro)),
      ],
      secondaryActions: [
        if (canSeePacks)
          ElumSecondaryButton(label: l10n.creditTopUpPackLink, onTap: () => choose(CreditTopUpChoice.seePacks)),
        ElumSecondaryButton(label: l10n.commonClose, onTap: () => Navigator.of(context).pop()),
      ],
    );
  }
}
