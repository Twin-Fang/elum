import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../core/l10n/l10n_context.dart';
import '../../../../core/theme/theme_context_ext.dart';
import '../../../../core/widgets/pro_badge.dart';
import '../../../../core/widgets/pro_upsell_button.dart';
import '../../../subscription/application/plan_paywall_entry.dart';
import '../../application/credit_costs.dart';

/// 내 크레딧 구독 카드 (Free 이고 Pro 를 살 수 있을 때만): PRO 배지 > 받는 크레딧 > 설명 > `7일 무료로 써 보기`
///
/// Pro 가 주는 개수를 앱이 모르므로 숫자 없는 문구. 버튼은 기존 요금제 화면을 엶 (체험 대상이 아니면 `Pro 알아보기`)
class MyCreditSubscribeCard extends ConsumerWidget {
  const MyCreditSubscribeCard({super.key});

  static const _padding = 20.0;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final space = context.space;
    final l10n = context.l10n;
    final periodUnit = ref.watch(creditPeriodUnitProvider);
    final actions = watchProUpsellActions(context, ref);
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [colors.proPlanTileCards, colors.proPlanTileWeek],
        ),
        borderRadius: BorderRadius.circular(space.cardRadius.r),
      ),
      child: Padding(
        padding: EdgeInsets.all(_padding.w),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Align(alignment: Alignment.centerLeft, child: ProBadge()),
            SizedBox(height: space.sm.h),
            Text(periodUnit.planBenefitMoreCredits(l10n), style: context.typo.cardTitle.copyWith(color: colors.textPrimary)),
            SizedBox(height: space.xs.h / 2),
            Text(l10n.myCreditSubscribeBody, style: context.typo.creditBody.copyWith(color: colors.textSecondary)),
            SizedBox(height: space.md.h),
            ProUpsellButton(style: ProUpsellStyle.filled, freeTrialLabel: actions.freeTrialLabel, onTap: actions.onStart),
          ],
        ),
      ),
    );
  }
}
