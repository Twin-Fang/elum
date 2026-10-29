import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../core/assets/app_assets.dart';
import '../../../../core/l10n/l10n_context.dart';
import '../../../../core/widgets/elum_pull_to_refresh.dart';
import '../../../../core/theme/theme_context_ext.dart';
import '../../../../core/widgets/elum_error_view.dart';
import '../../../../core/widgets/elum_spinner.dart';
import '../../../../core/widgets/elum_state_body.dart';
import '../../../notice/application/notice_history_controller.dart';
import '../../application/unread_summary_provider.dart';
import 'notice_history_card.dart';

/// 공지사항 탭: 공지 카드 목록, 끝에 닿으면 다음 쪽, 당겨서 새로고침
///
/// 처음 보일 때 한 번 `본 공지` 기록 > 안 읽음 요약 갱신 (실패해도 목록은 그대로)
class NoticeHistoryTab extends ConsumerStatefulWidget {
  const NoticeHistoryTab({super.key});

  @override
  ConsumerState<NoticeHistoryTab> createState() => _NoticeHistoryTabState();
}

class _NoticeHistoryTabState extends ConsumerState<NoticeHistoryTab> {
  final _scrollController = ScrollController();

  /// 끝까지 이만큼 남으면 다음 쪽을 받는다
  static const _loadMoreExtent = 320.0;
  static const _sidePadding = 16.0;
  static const _cardGap = 12.0;
  static const _emptyIllustrationSize = 160.0;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_loadMoreNearEnd);
    // 화면이 이 탭을 처음 만들 때 한 번 (탭을 오가도 화면이 위젯을 유지)
    WidgetsBinding.instance.addPostFrameCallback((_) => _markNoticesSeen());
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
      ref.read(noticeHistoryControllerProvider.notifier).loadMore();
    }
  }

  // 본 공지 기록 > 안 읽음 요약 갱신 (기록 실패도 요약은 다시 받음)
  Future<void> _markNoticesSeen() async {
    final isMarked = await ref
        .read(noticeHistoryControllerProvider.notifier)
        .markSeen();
    if (!mounted || !isMarked) return;
    await ref.read(unreadSummaryProvider.notifier).refresh();
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(noticeHistoryControllerProvider);
    final controller = ref.read(noticeHistoryControllerProvider.notifier);

    return switch (async) {
      AsyncData(value: final state) when state.items.isEmpty => ElumPullToRefresh(
          onRefresh: controller.refresh,
          failureMessage: context.l10n.notificationNoticeFailed,
          failureCode: 'E-NOTICE-HISTORY',
          child: ElumStateBody(child: _emptyBody(context)),
        ),
      AsyncData(value: final state) => ElumPullToRefresh(
          onRefresh: controller.refresh,
          failureMessage: context.l10n.notificationNoticeFailed,
          failureCode: 'E-NOTICE-HISTORY',
          child: _list(state),
        ),
      AsyncError(:final error) => ElumStateBody(
          child: ElumErrorView.failure(
            error,
            fallback: context.l10n.notificationNoticeFailed,
            fallbackCode: 'E-NOTICE-HISTORY',
            onRetry: controller.refresh,
          ),
        ),
      _ => const ElumStateBody.loading(),
    };
  }

  Widget _list(NoticeHistoryState state) {
    return ListView(
      controller: _scrollController,
      physics: const AlwaysScrollableScrollPhysics(),
      padding: EdgeInsets.fromLTRB(
        _sidePadding.w,
        context.space.md,
        _sidePadding.w,
        context.space.xl,
      ),
      children: [
        for (final notice in state.items) ...[
          NoticeHistoryCard(key: ValueKey(notice.id), notice: notice),
          SizedBox(height: _cardGap.h),
        ],
        if (state.isLoadingMore)
          Center(
            child: ElumSpinner(
              size: 24.w,
              color: context.colors.creditHistoryMutedText,
            ),
          ),
      ],
    );
  }

  // 알림 탭 빈 화면과 같은 모양 (루미 그림 + 문구)
  Widget _emptyBody(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Image.asset(
          AppAssets.notificationsEmptyLumi,
          width: _emptyIllustrationSize.w,
          height: _emptyIllustrationSize.w,
          fit: BoxFit.contain,
          excludeFromSemantics: true,
        ),
        SizedBox(height: context.space.lg),
        Text(
          context.l10n.notificationNoticeEmpty,
          textAlign: TextAlign.center,
          style: context.typo.creditHistoryRowTitle.copyWith(
            color: context.colors.textPrimary,
          ),
        ),
      ],
    );
  }
}
