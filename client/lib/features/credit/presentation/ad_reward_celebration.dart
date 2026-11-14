import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../core/assets/app_assets.dart';
import '../../../core/haptics/tap_haptics.dart';
import '../../../core/l10n/l10n_context.dart';
import '../../../core/theme/theme_context_ext.dart';
import '../../../core/widgets/app_celebration.dart';
import '../../../core/widgets/elum_dialog.dart';
import '../application/low_credit_notice.dart';

/// 광고 보상 받은 순간 창 본문: 축하 장면(표 그림 튐 > 제목 > 받은 이유 > 이전 > 지금 잔액 게이지, 햅틱) > 주 버튼 하나 (누르면 true)
///
/// 받은 수를 모르면 숫자 없는 제목. 잔액 조회가 실패하면 게이지 없음. 게이지 가득 = 일과 1개 어림 크레딧
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
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppCelebration(
          illustrationAsset: AppAssets.creditRewardBurst,
          title: grantedCredits > 0 ? l10n.creditRewardTitle(grantedCredits) : l10n.creditRewardTitleNoCount,
          reasonText: l10n.creditRewardReason,
          gauge: balance == null
              ? null
              : AppCelebrationGauge(
                  // 받기 전 잔액에서 차오름
                  before: (balance - grantedCredits).clamp(0, balance),
                  after: balance,
                  maximum: lowCreditRoutineEstimate,
                  valueFormat: l10n.creditGuideCount,
                ),
        ),
        SizedBox(height: context.space.md.h),
        ElumDialogButton(label: buttonLabel, onTap: withTapHaptic(() => Navigator.of(context).pop(true))),
      ],
    );
  }
}
