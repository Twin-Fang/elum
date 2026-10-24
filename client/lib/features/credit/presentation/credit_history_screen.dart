import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../core/l10n/l10n_context.dart';
import '../../../core/network/app_failure.dart';
import '../../../core/router/pop_or_home.dart';
import '../../../core/theme/theme_context_ext.dart';
import '../../../core/widgets/app_pressable.dart';
import '../../../core/widgets/elum_empty_illustration.dart';
import '../../../core/widgets/elum_error_view.dart';
import '../../../core/widgets/elum_scaffold.dart';
import '../../../core/widgets/elum_spinner.dart';
import '../../../core/widgets/elum_state_body.dart';
import '../application/credit_history_notifier.dart';
import '../domain/credit_history.dart';
import 'widgets/credit_history_day_card.dart';

/// 크레딧 사용 내역 — 설정 크레딧 카드의 `크레딧 사용 내역 보기`로 들어온다 (Figma `1589:8359`).
///
/// 최근 것부터 날짜별 흰 카드로 보이고, 끝에 닿으면 다음 쪽을 이어 받는다. 상태는 넷이다:
/// 불러오는 중 / 0건 / 실패(다시 하기 + 에러 코드) / 목록. 0건과 실패는 서로 다른 화면이다 —
/// 못 불러온 것을 "쓴 적 없다"로 보이면 안 된다.
class CreditHistoryScreen extends ConsumerStatefulWidget {
  const CreditHistoryScreen({super.key});

  static const emptyKey = ValueKey('credit-history-empty');
  static const listKey = ValueKey('credit-history-list');
  static const moreFailedKey = ValueKey('credit-history-more-failed');

  @override
  ConsumerState<CreditHistoryScreen> createState() =>
      _CreditHistoryScreenState();
}

class _CreditHistoryScreenState extends ConsumerState<CreditHistoryScreen> {
  final _scrollController = ScrollController();

  /// 첫 날짜가 y131 에서 시작한다: 스크롤 고정 영역(115) 아래로 8 + 16 (설정 메인과 같다)
  static const _firstDateTopGap = 16.0;

  /// 날짜 묶음 사이 (Figma `1589:8519` gap 24)
  static const _dayGap = 24.0;

  /// 끝까지 이만큼 남으면 다음 쪽을 받는다.
  static const _loadMoreExtent = 320.0;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_loadMoreNearEnd);
  }

  @override
  void dispose() {
    _scrollController
      ..removeListener(_loadMoreNearEnd)
      ..dispose();
    super.dispose();
  }

  void _loadMoreNearEnd() {
    if (_scrollController.position.extentAfter < _loadMoreExtent) {
      ref.read(creditHistoryProvider.notifier).loadMore();
    }
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(creditHistoryProvider);

    return ElumScaffold(
      onBack: context.popOrHome,
      title: context.l10n.creditHistoryTitle,
      backTop: 67,
      horizontalPadding: 16,
      child: Padding(
        padding: EdgeInsets.only(top: 8.h),
        child: switch (async) {
          AsyncData(value: final state) when state.entries.isEmpty =>
            ElumStateBody(child: _EmptyBody(key: CreditHistoryScreen.emptyKey)),
          AsyncData(value: final state) => _list(state),
          AsyncError(:final error) => ElumStateBody(
            child: ElumErrorView.failure(
              error,
              fallback: context.l10n.creditHistoryLoadFailed,
              fallbackCode: 'E-CREDIT-HISTORY',
              onRetry: () => ref.invalidate(creditHistoryProvider),
            ),
          ),
          _ => const ElumStateBody.loading(),
        },
      ),
    );
  }

  Widget _list(CreditHistoryState state) {
    final days = groupCreditHistoryByDay(state.entries);
    return SingleChildScrollView(
      key: CreditHistoryScreen.listKey,
      controller: _scrollController,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(height: _firstDateTopGap.h),
          for (final day in days) ...[
            CreditHistoryDayCard(day: day),
            SizedBox(height: _dayGap.h),
          ],
          if (state.isLoadingMore)
            Padding(
              padding: EdgeInsets.only(bottom: _dayGap.h),
              child: Center(
                child: ElumSpinner(
                  size: 24.w,
                  color: context.colors.creditHistoryMutedText,
                ),
              ),
            ),
          if (state.moreFailure case final failure?)
            _MoreFailedRow(
              failure: failure,
              onRetry: () =>
                  ref.read(creditHistoryProvider.notifier).loadMore(),
            ),
        ],
      ),
    );
  }
}

/// 0건: 비었다는 말과 다음 행동 (로딩·실패와 다른 화면이다).
class _EmptyBody extends StatelessWidget {
  const _EmptyBody({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const ElumEmptyIllustration(),
        SizedBox(height: context.space.lg),
        Text(
          context.l10n.creditHistoryEmptyTitle,
          textAlign: TextAlign.center,
          style: context.typo.creditHistoryRowTitle.copyWith(
            color: colors.settingsCardLabel,
          ),
        ),
        SizedBox(height: context.space.xs),
        Text(
          context.l10n.creditHistoryEmptyBody,
          textAlign: TextAlign.center,
          style: context.typo.creditHistoryRowDetail.copyWith(
            color: colors.creditHistoryMutedText,
          ),
        ),
      ],
    );
  }
}

/// 다음 쪽 실패: 받아 둔 내역은 그대로 두고 아래에 다시 하기와 코드를 둔다.
class _MoreFailedRow extends StatelessWidget {
  const _MoreFailedRow({required this.failure, required this.onRetry});

  final AppFailure failure;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Padding(
      key: CreditHistoryScreen.moreFailedKey,
      padding: EdgeInsets.only(bottom: context.space.md),
      child: AppPressable(
        onTap: onRetry,
        semanticLabel: context.l10n.creditCardRetry,
        child: Center(
          child: Text(
            '${context.l10n.creditHistoryMoreFailed} · ${context.l10n.creditCardRetry} (${failure.badgeOr('E-CREDIT-HISTORY')})',
            textAlign: TextAlign.center,
            style: context.typo.creditHistoryRowDetail.copyWith(
              color: colors.creditHistoryMutedText,
            ),
          ),
        ),
      ),
    );
  }
}
