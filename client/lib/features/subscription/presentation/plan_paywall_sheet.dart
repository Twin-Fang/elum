import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../core/layout/layout_context_ext.dart';
import '../../../core/theme/theme_context_ext.dart';
import '../../../core/widgets/elum_bottom_sheet.dart';
import '../../../core/widgets/elum_dialog.dart';
import '../application/plan_purchase_notifier.dart';
import '../domain/plan_benefit.dart';
import '../domain/plan_purchase_state.dart';
import 'plan_paywall_body.dart';

/// 요금제 화면 열기 (#1189 시안 A): 폰 > 바닥 시트, 태블릿 > 가운데 카드. 닫히면 결제 단계 정리
/// [highlight]: 혜택 묶음 맨 위로 올릴 혜택 (연 기능)
Future<void> showPlanPaywall(BuildContext context, WidgetRef ref, {PlanBenefit? highlight}) async {
  final isTablet = context.layoutMetrics.isScaleOverridden;
  if (isTablet) {
    await showElumDialogContent<void>(
      context: context,
      barrierDismissible: true,
      builder: (_) => _PlanPaywallCard(highlight: highlight),
    );
  } else {
    await showElumSheet<void>(
      context: context,
      builder: (_) => _PlanPaywallSheet(highlight: highlight),
    );
  }
  // 결제창·확인이 아직 돌면 그대로 둠 (다시 열면 그 단계가 보임)
  ref.read(planPurchaseStateProvider.notifier).apply(const PlanPurchaseEvent.dismissed());
}

/// 폰: 바닥 시트 (상태 표시줄 아래까지 자람, 내용이 짧으면 그만큼만)
class _PlanPaywallSheet extends StatelessWidget {
  const _PlanPaywallSheet({this.highlight});

  final PlanBenefit? highlight;

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    // 바닥 시트 라우트가 안쪽 MediaQuery 의 top 을 지우므로 창 기준으로 읽음 (ElumSheetFrame 과 같음)
    final statusBarHeight = MediaQueryData.fromView(View.of(context)).viewPadding.top;
    final availableHeight = media.size.height - statusBarHeight - context.space.md.h;
    return ElumSheetSurface(
      clipBehavior: Clip.antiAlias,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: math.max(0, availableHeight)),
        child: PlanPaywallBody(highlight: highlight, bottomInset: media.padding.bottom),
      ),
    );
  }
}

/// 태블릿: 가운데 카드 (시트 폭 상한, 창 높이의 85% 까지)
class _PlanPaywallCard extends StatelessWidget {
  const _PlanPaywallCard({this.highlight});

  final PlanBenefit? highlight;

  /// 카드가 쓸 수 있는 창 높이 비율 (위아래 숨 쉴 자리)
  static const _maxHeightRatio = 0.85;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Material(
        type: MaterialType.transparency,
        child: Container(
          constraints: BoxConstraints(
            maxWidth: context.layout.sheetMaxWidth.w,
            maxHeight: MediaQuery.sizeOf(context).height * _maxHeightRatio,
          ),
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: context.colors.background,
            borderRadius: BorderRadius.circular(context.space.cardRadius.r),
          ),
          child: PlanPaywallBody(highlight: highlight, bottomInset: 0),
        ),
      ),
    );
  }
}
