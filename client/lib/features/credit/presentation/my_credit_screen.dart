import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../core/assets/app_assets.dart';
import '../../../core/l10n/l10n_context.dart';
import '../../../core/router/pop_or_home.dart';
import '../../../core/haptics/tap_haptics.dart';
import '../../../core/theme/app_motion.dart';
import '../../../core/theme/theme_context_ext.dart';
import '../../../core/widgets/app_fade_slide_in.dart';
import '../../../core/widgets/app_pressable.dart';
import '../../../core/widgets/elum_error_view.dart';
import '../../../core/widgets/elum_scaffold.dart';
import '../../../core/widgets/elum_state_body.dart';
import '../../member/application/plan_access.dart';
import '../../subscription/application/credit_purchase_notifier.dart';
import '../application/credit_cost_guide_entry.dart';
import '../data/credit_repository.dart';
import '../domain/credit_purchase.dart';
import '../domain/credit_summary.dart';
import 'credit_purchase_actions.dart';
import 'widgets/my_credit_activity.dart';
import 'widgets/my_credit_balance_card.dart';
import 'widgets/my_credit_pack_section.dart';
import 'widgets/my_credit_subscribe_card.dart';

/// 내 크레딧: 제목 + 물음표(크레딧 안내 창) > 잔액 카드(요금제 배지 포함) > (Free) 구독 카드 > 꾸러미 > 최근 쓴 내역 카드 3줄 (#1322)
/// 상태 4개: 불러오는 중 · 실패(다시 하기 + 코드) · 꺼짐(빈 화면) · 정상 (꾸러미 실패와 무관하게 잔액은 보임)
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
    // 묶음이 위에서부터 차례로 떠오름 (동작 줄이기면 바로 보임)
    Widget stagger(int order, Widget child) => AppFadeSlideIn(delay: AppMotion.sectionStagger * order, child: child);
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _TitleWithGuideButton(summary: summary),
          SizedBox(height: context.space.md.h),
          stagger(0, MyCreditBalanceCard(summary: summary)),
          if (access.shouldShowProTeaser) ...[
            SizedBox(height: _sectionGap.h),
            stagger(1, Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: EdgeInsets.only(left: context.space.xs.w, bottom: context.space.xs.h),
                  child: Text(context.l10n.myCreditSubscribeLabel, style: context.typo.settingsGroupLabel.copyWith(color: colors.settingsGroupLabel)),
                ),
                const MyCreditSubscribeCard(),
              ],
            )),
          ],
          // 할 수 있는 행동(사기)을 지난 기록(내역)보다 먼저
          SizedBox(height: _sectionGap.h),
          stagger(2, const MyCreditPackSection()),
          SizedBox(height: _sectionGap.h),
          stagger(3, const MyCreditRecentHistory()),
          SizedBox(height: _bottomGap.h),
        ],
      ),
    );
  }
}

/// 제목 `내 크레딧` + 물음표: 누르면 크레딧 안내 창 (내 요금제 기준 단가 · 지급량). 제목 줄 전체가 누름 영역
class _TitleWithGuideButton extends ConsumerWidget {
  const _TitleWithGuideButton({required this.summary});

  final CreditSummary summary;

  static const _titleToIconGap = 6.0;
  static const _iconSize = 20.0;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    return Align(
      alignment: Alignment.centerLeft,
      child: AppPressable(
        scaleDown: AppPressable.scaleIcon,
        semanticLabel: context.l10n.creditInfoLabel,
        onTap: withTapHaptic(() => showCreditCostGuide(context, ref, summary)),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(child: Text(context.l10n.myCreditTitle, style: context.typo.libraryTitle.copyWith(color: colors.textPrimary))),
            SizedBox(width: _titleToIconGap.w),
            SvgPicture.asset(
              AppAssets.iconQuestionCircle,
              width: _iconSize.w,
              height: _iconSize.w,
              excludeFromSemantics: true,
              colorFilter: ColorFilter.mode(colors.creditMutedText, BlendMode.srcIn),
            ),
          ],
        ),
      ),
    );
  }
}
