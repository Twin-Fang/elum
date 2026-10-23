import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';

import '../../../core/l10n/l10n_context.dart';
import '../../../core/router/pop_or_home.dart';
import '../../../core/router/routes.dart';
import '../../../core/theme/theme_context_ext.dart';
import '../../../core/widgets/app_pressable.dart';
import '../../../core/widgets/elum_error_view.dart';
import '../../../core/widgets/elum_scaffold.dart';
import '../../../core/widgets/elum_spinner.dart';
import '../../../core/widgets/elum_state_body.dart';
import '../application/talk_feed_controller.dart';
import '../application/talk_my_posts_controller.dart';
import '../domain/talk_post.dart';
import '../domain/talk_screen_codes.dart';
import 'widgets/talk_empty_message.dart';
import 'widgets/talk_post_card.dart';

/// 내가 쓴 글 (내 정보 > 내가 쓴 글): 내가 이야기에 올린 글을 최신순으로, 카드를 누르면 글 상세
/// 상태: 받는 중 / 0건(일과 나누기로) / 첫 쪽 실패(다시 하기 + 에러 코드) / 목록 (더 받기 실패는 끝 줄)
class TalkMyPostsScreen extends ConsumerStatefulWidget {
  const TalkMyPostsScreen({super.key});

  @override
  ConsumerState<TalkMyPostsScreen> createState() => _TalkMyPostsScreenState();
}

class _TalkMyPostsScreenState extends ConsumerState<TalkMyPostsScreen> {
  final _scrollController = ScrollController();

  /// 끝까지 이만큼 남으면 다음 쪽을 받는다
  static const _loadMoreExtent = 320.0;

  /// 목록 위아래 · 카드 사이 (피드와 같은 8)
  static const _listPadV = 16.0;
  static const _cardGap = 8.0;

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
      ref.read(talkMyPostsControllerProvider.notifier).loadMore();
    }
  }

  void _openPost(TalkPostSummary post) =>
      context.push(Routes.guardianTalkPostOf(post.id));

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final myPosts = ref.watch(talkMyPostsControllerProvider);

    return ElumScaffold(
      onBack: context.popOrHome,
      title: l10n.talkMyPostsTitle,
      backTop: 67,
      horizontalPadding: 16,
      child: switch (myPosts) {
        AsyncData(value: final state) when state.items.isEmpty =>
          ElumStateBody(
            child: TalkEmptyMessage(
              title: l10n.talkMyPostsEmpty,
              actionLabel: l10n.talkMyPostsEmptyAction,
              onActionPressed: () => context.push(Routes.guardianTalkShare),
            ),
          ),
        AsyncData(value: final state) => _list(state),
        AsyncError(:final error) => ElumStateBody(
          child: ElumErrorView.failure(
            error,
            fallback: l10n.talkMyPostsFailed,
            fallbackCode: TalkScreenCodes.myPosts,
            onRetry: () => ref.invalidate(talkMyPostsControllerProvider),
          ),
        ),
        _ => const ElumStateBody.loading(),
      },
    );
  }

  Widget _list(TalkFeedState state) {
    return ListView(
      controller: _scrollController,
      padding: EdgeInsets.symmetric(vertical: _listPadV.h),
      children: [
        for (final post in state.items)
          Padding(
            padding: EdgeInsets.only(bottom: _cardGap.h),
            child: TalkPostCard(
              key: ValueKey(post.id),
              post: post,
              onTap: () => _openPost(post),
            ),
          ),
        if (state.isLoadingMore)
          Padding(
            padding: EdgeInsets.only(top: context.space.xs.h),
            child: Center(
              child: ElumSpinner(
                size: 24.w,
                color: context.colors.creditHistoryMutedText,
              ),
            ),
          ),
        if (state.hasLoadMoreFailed)
          AppPressable(
            onTap: ref.read(talkMyPostsControllerProvider.notifier).retryLoadMore,
            scaleDown: AppPressable.scaleCard,
            child: Padding(
              padding: EdgeInsets.symmetric(vertical: context.space.md.h),
              child: Center(
                child: Text(
                  context.l10n.talkLoadMoreRetry,
                  textAlign: TextAlign.center,
                  style: context.typo.talkGuide.copyWith(
                    color: context.colors.talkMetaText,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
