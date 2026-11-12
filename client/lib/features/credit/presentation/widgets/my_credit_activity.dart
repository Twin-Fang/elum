import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/haptics/tap_haptics.dart';
import '../../../../core/l10n/l10n_context.dart';
import '../../../../core/network/app_failure.dart';
import '../../../../core/router/routes.dart';
import '../../../../core/theme/theme_context_ext.dart';
import '../../../../core/widgets/app_pressable.dart';
import '../../../../core/widgets/elum_error_code_text.dart';
import '../../../../core/widgets/elum_spinner.dart';
import '../../../../core/widgets/elum_text_link.dart';
import '../../../../core/widgets/min_tap_target.dart';
import '../../application/credit_history_notifier.dart';
import '../../domain/credit_history.dart';
import 'credit_history_day_card.dart';

/// 최근 쓴 내역: 머리글 `최근 쓴 내역` | `전체 보기 ›` > 첫 쪽에서 5줄 (내역 화면의 하루치 카드 그대로)
///
/// 상태 4개: 불러오는 중(작은 스피너) · 실패(한 줄 + 다시 하기 + 코드) · 0건(빈 상태 한 줄) · 줄
/// 머리글 왼쪽은 날짜 머리글과 같은 여백 ([CreditHistoryDayCard.dateInsetLeft])
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
    final inset = CreditHistoryDayCard.dateInsetLeft.w;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // 머리글: 왼쪽 제목 | 오른쪽 `전체 보기 ›` (줄이 있을 때만)
        Padding(
          padding: EdgeInsets.symmetric(horizontal: inset),
          child: Row(
            children: [
              Expanded(
                child: Text(l10n.myCreditRecentTitle, style: context.typo.settingsGroupLabel.copyWith(color: colors.settingsGroupLabel)),
              ),
              if (hasEntries) const _SeeAllHistoryButton(),
            ],
          ),
        ),
        body,
      ],
    );
  }
}

/// `전체 보기 ›`: 크레딧 사용 내역 화면으로 (보이는 글자는 작고 누르는 영역은 44)
class _SeeAllHistoryButton extends StatelessWidget {
  const _SeeAllHistoryButton();

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return AppPressable(
      onTap: withTapHaptic(() => context.push(Routes.guardianCreditHistory)),
      child: MinTapTarget(
        child: Text(
          '${context.l10n.myCreditSeeAllHistory} ›',
          style: context.typo.settingsGroupLabel.copyWith(color: colors.settingsGroupLabel),
        ),
      ),
    );
  }
}
