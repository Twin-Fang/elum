import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../core/l10n/l10n_context.dart';
import '../../../core/router/pop_or_home.dart';
import '../../../core/theme/theme_context_ext.dart';
import '../../../core/widgets/elum_error_view.dart';
import '../../../core/widgets/elum_scaffold.dart';
import '../../../core/widgets/elum_state_body.dart';
import '../../../core/widgets/free_badge.dart';
import '../../../core/widgets/pro_badge.dart';
import '../../member/application/plan_access.dart';
import '../../subscription/application/credit_purchase_notifier.dart';
import '../data/credit_repository.dart';
import '../domain/credit_purchase.dart';
import '../domain/credit_summary.dart';
import 'credit_purchase_actions.dart';
import 'widgets/my_credit_balance_card.dart';
import 'widgets/my_credit_pack_section.dart';
import 'widgets/my_credit_subscribe_card.dart';

/// 내 크레딧: 머리(제목 + 요금제 태그) > 종류별 잔액 카드 > (Free) 구독 카드 > 크레딧 꾸러미 구매
///
/// 상태: 불러오는 중 / 실패(다시 하기 + 코드) / 크레딧 꺼짐(빈 화면) / 잔액 + 구독·꾸러미.
/// 꾸러미 구역이 실패하거나 꺼져도 위쪽 잔액은 그대로 보임
class MyCreditScreen extends ConsumerWidget {
  const MyCreditScreen({super.key});

  static const _headerTopGap = 8.0;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // 받음 > 알림 띠, 되돌릴 수 없는 실패 > 팝업 (한 번씩)
    ref.listen(creditPurchaseStateProvider, (previous, next) {
      if (next.phase == previous?.phase) return;
      if (next.phase == CreditPurchasePhase.granted || next.phase == CreditPurchasePhase.failed) {
        showCreditPurchaseOutcome(context, ref, next);
      }
    });
    final async = ref.watch(creditSummaryProvider);
    final isBusy = ref.watch(creditPurchaseStateProvider.select((state) => state.isBusy));
    return ElumScaffold(
      onBack: context.popOrHome,
      isBackEnabled: !isBusy,
      backTop: ElumScaffold.settingsBackTop,
      horizontalPadding: 16,
      child: Padding(
        padding: EdgeInsets.only(top: _headerTopGap.h),
        child: switch (async) {
          AsyncData(value: final summary) when !summary.enabled => const ElumStateBody(child: SizedBox.shrink()),
          AsyncData(value: final summary) => _Body(summary: summary),
          AsyncError(:final error) => ElumStateBody(
            child: ElumErrorView.failure(
              error,
              fallback: context.l10n.creditCardLoadFailed,
              fallbackCode: 'E-CREDIT-MINE',
              onRetry: () => ref.invalidate(creditSummaryProvider),
            ),
          ),
          _ => const ElumStateBody.loading(),
        },
      ),
    );
  }
}

class _Body extends ConsumerWidget {
  const _Body({required this.summary});

  final CreditSummary summary;

  static const _sectionGap = 24.0;
  static const _bottomGap = 24.0;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final access = ref.watch(planAccessProvider);
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(child: Text(context.l10n.myCreditTitle, style: context.typo.libraryTitle.copyWith(color: colors.textPrimary))),
              access.isPro ? const ProBadge() : const FreeBadge(),
            ],
          ),
          SizedBox(height: context.space.md.h),
          MyCreditBalanceCard(summary: summary),
          if (access.shouldShowProTeaser) ...[
            SizedBox(height: _sectionGap.h),
            Padding(
              padding: EdgeInsets.only(left: context.space.xs.w, bottom: context.space.xs.h),
              child: Text(context.l10n.myCreditSubscribeLabel, style: context.typo.settingsGroupLabel.copyWith(color: colors.settingsGroupLabel)),
            ),
            const MyCreditSubscribeCard(),
          ],
          SizedBox(height: _sectionGap.h),
          const MyCreditPackSection(),
          SizedBox(height: _bottomGap.h),
        ],
      ),
    );
  }
}
