import 'package:flutter/material.dart';

import '../../../core/assets/app_assets.dart';
import '../../../core/l10n/l10n_context.dart';
import '../../../core/widgets/elum_guide_panel.dart';

/// 광고 보상 받은 순간 창 (안내 뼈대): 크레딧 반짝 그림 튀어 오름 + `+N` 세기 > 제목 > 받은 이유 > 지금 잔액(세기) > 버튼 하나 (누르면 true)
///
/// 받은 수를 모르면 `+N` 없이 `크레딧을 받았어요`. 잔액 조회가 실패하면 잔액 줄 없음
class AdRewardCelebration extends StatelessWidget {
  const AdRewardCelebration({
    super.key,
    required this.grantedCredits,
    required this.balance,
    required this.buttonLabel,
  });

  /// 받은 크레딧 (0 이면 모름)
  final int grantedCredits;

  /// 받은 뒤 잔액 (조회 실패면 null)
  final int? balance;
  final String buttonLabel;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final balance = this.balance;
    return ElumGuidePanel(
      placement: ElumGuidePlacement.dialog,
      illustration: ElumGuideRewardIllustration(asset: AppAssets.creditRewardBurst, amount: grantedCredits),
      title: grantedCredits > 0 ? l10n.creditRewardTitle(grantedCredits) : l10n.creditRewardTitleNoCount,
      description: l10n.creditRewardReason,
      content: [
        if (balance != null)
          ElumGuideCountUpRow(
            iconAsset: AppAssets.iconCoins,
            label: l10n.creditRewardBalanceLabel,
            // 받기 전 잔액에서 세며 올라감
            from: (balance - grantedCredits).clamp(0, balance),
            to: balance,
            format: l10n.creditGuideCount,
          ),
      ],
      primaryAction: ElumGuideAction(label: buttonLabel, onTap: () => Navigator.of(context).pop(true)),
    );
  }
}
