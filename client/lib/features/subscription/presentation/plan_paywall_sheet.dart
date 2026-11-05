import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../core/l10n/l10n_context.dart';
import '../../../core/layout/layout_context_ext.dart';
import '../../../core/theme/theme_context_ext.dart';
import '../../../core/widgets/elum_bottom_sheet.dart';
import '../../../core/widgets/elum_dialog.dart';
import '../../../core/widgets/elum_sheet_frame.dart';
import '../application/plan_purchase_notifier.dart';
import '../domain/plan_benefit.dart';
import '../domain/plan_purchase_state.dart';
import 'plan_paywall_body.dart';

/// 요금제 화면 열기 (시안 #1070 A안): 폰 > 바닥 시트, 태블릿 > 가운데 카드. 닫히면 결제 단계 정리
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

/// 결제 진행 중에는 뒤로가기·바깥 누르기로 닫지 않음
class _BusyPopGuard extends ConsumerWidget {
  const _BusyPopGuard({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isBusy = ref.watch(planPurchaseStateProvider.select((state) => state.isBusy));
    return PopScope(canPop: !isBusy, child: child);
  }
}

/// 폰: 시트 틀(제목 · 설명 · 본문, 큰 글자면 시트 안 스크롤)
class _PlanPaywallSheet extends StatelessWidget {
  const _PlanPaywallSheet({this.highlight});

  final PlanBenefit? highlight;

  @override
  Widget build(BuildContext context) {
    return _BusyPopGuard(
      child: ElumSheetFrame(
        title: context.l10n.planPaywallTitle,
        description: context.l10n.planPaywallDescription,
        child: PlanPaywallBody(highlight: highlight),
      ),
    );
  }
}

/// 태블릿: 팝업 카드(322) 안에 같은 내용, 창 높이를 넘으면 카드 안 스크롤
class _PlanPaywallCard extends StatelessWidget {
  const _PlanPaywallCard({this.highlight});

  final PlanBenefit? highlight;

  /// 카드가 쓸 수 있는 창 높이 비율 (위아래 숨 쉴 자리)
  static const _maxHeightRatio = 0.85;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typo = context.typo;
    return _BusyPopGuard(
      child: Center(
        child: Material(
          type: MaterialType.transparency,
          child: ElumDialogSurface(
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.sizeOf(context).height * _maxHeightRatio,
              ),
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      context.l10n.planPaywallTitle,
                      style: typo.sheetTitle.copyWith(color: colors.sheetTitleText),
                    ),
                    SizedBox(height: context.space.xs.h),
                    Text(
                      context.l10n.planPaywallDescription,
                      style: typo.sheetDescription.copyWith(color: colors.sheetTitleText),
                    ),
                    SizedBox(height: context.space.lg.h),
                    PlanPaywallBody(highlight: highlight),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
