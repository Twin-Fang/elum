import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/assets/app_assets.dart';
import '../../../../core/haptics/tap_haptics.dart';
import '../../../../core/l10n/l10n_context.dart';
import '../../../../core/network/app_failure.dart';
import '../../../../core/router/routes.dart';
import '../../../../core/theme/theme_context_ext.dart';
import '../../../../core/widgets/ai_credit_bar.dart';
import '../../../../core/widgets/elum_error_code_text.dart';
import '../../../../core/widgets/elum_guide_panel.dart';
import '../../../../core/widgets/elum_spinner.dart';
import '../../../../core/widgets/elum_text_link.dart';
import '../../../member/application/plan_access.dart';
import '../../application/credit_history_notifier.dart';
import '../../domain/credit_history.dart';
import '../../domain/credit_summary.dart';
import 'credit_history_day_card.dart';

/// 이번 주기 사용 카드: `이번 주에 N개 쓰고 M개 남았어요` > 남은 비율 막대 > (Pro) 오늘 무료 다시 그리기 한 줄
class MyCreditUsageCard extends ConsumerWidget {
  const MyCreditUsageCard({super.key, required this.summary});

  final CreditSummary summary;

  static const _padding = 20.0;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final space = context.space;
    final l10n = context.l10n;
    final canRegenerateImagesFree = ref.watch(planAccessProvider.select((access) => access.canRegenerateImagesFree));
    final dailyCap = summary.freeImageRegenerateDailyCap;
    final usageLine = summary.periodUnit.isMonth
        ? l10n.myCreditUsageMonth(summary.used, summary.available)
        : l10n.myCreditUsageWeek(summary.used, summary.available);
    return DecoratedBox(
      decoration: BoxDecoration(color: colors.surface, borderRadius: BorderRadius.circular(space.cardRadius.r)),
      child: Padding(
        padding: EdgeInsets.all(_padding.w),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(usageLine, style: context.typo.creditBody.copyWith(color: colors.textPrimary)),
            SizedBox(height: space.xs.h),
            AiCreditBar(ratio: summary.remainingRatio, color: colors.creditBarFill),
            // Pro 무료 다시 그리기 (서버 하루 한도를 받았을 때만)
            if (canRegenerateImagesFree && dailyCap > 0) ...[
              SizedBox(height: space.sm.h),
              ElumGuideNote(
                iconAsset: AppAssets.iconRefresh,
                text: l10n.myCreditFreeRegenerateToday(summary.freeImageRegeneratesLeftToday, dailyCap),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// 최근 쓴 내역: 묶음 제목 > 첫 쪽에서 5줄 (내역 화면의 하루치 카드 그대로) > `전체 내역 보기`
///
/// 상태 4개: 불러오는 중(작은 스피너) · 실패(한 줄 + 다시 하기 + 코드) · 0건(빈 상태 한 줄) · 줄
class MyCreditRecentHistory extends ConsumerWidget {
  const MyCreditRecentHistory({super.key});

  /// 바로 보여 줄 줄 수
  static const _recentEntryCount = 5;
  static const _spinnerSize = 24.0;
  static const _failureCode = 'E-CREDIT-HISTORY';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final space = context.space;
    final l10n = context.l10n;
    final async = ref.watch(creditHistoryProvider);
    final mutedStyle = context.typo.creditBody.copyWith(color: colors.textSecondary);
    final body = switch (async) {
      AsyncData(value: final state) when state.entries.isEmpty =>
        Text(l10n.creditHistoryEmptyTitle, textAlign: TextAlign.center, style: mutedStyle),
      AsyncData(value: final state) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final (index, day) in groupCreditHistoryByDay(state.entries.take(_recentEntryCount).toList()).indexed) ...[
            if (index > 0) SizedBox(height: space.sm.h),
            CreditHistoryDayCard(day: day),
          ],
        ],
      ),
      AsyncError(:final error) => Column(
        children: [
          Text(l10n.creditHistoryLoadFailed, textAlign: TextAlign.center, style: mutedStyle),
          ElumErrorCodeText(AppFailure.of(error).badgeOr(_failureCode)),
          ElumTextLink(label: l10n.creditCardRetry, onTap: withTapHaptic(() => ref.invalidate(creditHistoryProvider))),
        ],
      ),
      _ => Center(child: ElumSpinner(size: _spinnerSize.w, color: colors.creditHistoryMutedText)),
    };
    final hasEntries = async.value?.entries.isNotEmpty ?? false;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: EdgeInsets.only(left: space.xs.w, bottom: space.xs.h),
          child: Text(l10n.myCreditRecentTitle, style: context.typo.settingsGroupLabel.copyWith(color: colors.settingsGroupLabel)),
        ),
        body,
        if (hasEntries)
          ElumTextLink(
            label: l10n.myCreditSeeAllHistory,
            onTap: withTapHaptic(() => context.push(Routes.guardianCreditHistory)),
          ),
      ],
    );
  }
}
