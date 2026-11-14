import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../core/assets/app_assets.dart';
import '../../../../core/haptics/tap_haptics.dart';
import '../../../../core/l10n/batchim.dart';
import '../../../../core/l10n/l10n_context.dart';
import '../../../../core/theme/theme_context_ext.dart';
import '../../../../core/widgets/app_celebration.dart';
import '../../../../core/widgets/elum_dialog.dart';
import '../../../../core/widgets/elum_guide_panel.dart';

/// 연속 기록 축하 창 띄우기 (보호자 홈, 축하 일수마다 한 번): 불꽃 그림 튐 > 제목 > 이유 한 줄 > 확인
Future<void> showStreakMilestoneDialog(BuildContext context, {required int milestoneDays, required String elumiName}) {
  return showElumGuideDialog<void>(
    context: context,
    builder: (_) => StreakMilestoneCelebrationBody(milestoneDays: milestoneDays, elumiName: elumiName),
  );
}

/// 연속 기록 축하 창 본문 (개발자 도구 · 렌더 확인에서도 바로 세움)
class StreakMilestoneCelebrationBody extends StatelessWidget {
  const StreakMilestoneCelebrationBody({super.key, required this.milestoneDays, required this.elumiName});

  /// 닿은 축하 일수 (3 · 7 · 14 · 30)
  final int milestoneDays;
  final String elumiName;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppCelebration(
          illustrationAsset: AppAssets.celebrationStreak,
          title: l10n.streakMilestoneTitle(milestoneDays),
          reasonText: l10n.streakMilestoneReason(elumiName, batchimOf(elumiName)),
        ),
        SizedBox(height: context.space.md.h),
        ElumDialogButton(label: l10n.commonConfirm, onTap: withTapHaptic(() => Navigator.of(context).pop())),
      ],
    );
  }
}
