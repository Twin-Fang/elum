import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';

import '../../../core/assets/app_assets.dart';
import '../../../core/l10n/l10n_context.dart';
import '../../../core/router/routes.dart';
import '../../../core/theme/theme_context_ext.dart';
import '../../../core/widgets/app_pressable.dart';
import '../../../core/widgets/elum_button.dart';
import '../../../core/widgets/elum_error_view.dart';
import '../../../core/widgets/elum_spinner.dart';
import '../../../core/widgets/elum_state_body.dart';
import '../../guardian/domain/routine_template.dart';
import '../application/talk_feed_controller.dart';
import '../application/talk_popular_provider.dart';
import '../domain/talk_post.dart';
import 'widgets/talk_category_chips.dart';
import 'widgets/talk_import_sheet.dart';
import 'widgets/talk_popular_row.dart';
import 'widgets/talk_post_card.dart';

/// 하단 바 이야기 칸: 제목 + 올리기 > 분류 칩 > 인기 줄 > 최신 글 무한 스크롤
/// 상태: 받는 중 / 0건 / 첫 쪽 실패(다시 하기 + 에러 코드) / 목록 (인기 줄은 실패해도 숨기기만 함)
class TalkFeedScreen extends ConsumerStatefulWidget {
  const TalkFeedScreen({super.key});

  @override
  ConsumerState<TalkFeedScreen> createState() => _TalkFeedScreenState();
}

class _TalkFeedScreenState extends ConsumerState<TalkFeedScreen> {
  final _scrollController = ScrollController();

  /// 고른 분류. null 이면 전체
  RoutineTemplateCategory? _selectedCategory;

  /// 끝까지 이만큼 남으면 다음 쪽을 받는다
  static const _loadMoreExtent = 320.0;
  static const _cardGap = 12.0;
  static const _sectionGap = 20.0;

  String? get _categoryValue => _selectedCategory?.serverValue;

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
      ref.read(talkFeedControllerProvider(_categoryValue).notifier).loadMore();
    }
  }

  void _onCategorySelected(RoutineTemplateCategory? category) {
    if (category == _selectedCategory) return;
    setState(() => _selectedCategory = category);
    // 다른 분류의 목록은 맨 위부터
    if (_scrollController.hasClients) _scrollController.jumpTo(0);
  }

  void _openPost(TalkPostSummary post) =>
      context.push(Routes.guardianTalkPostOf(post.id));

  void _openShare() => context.push(Routes.guardianTalkShare);

  /// 당겨서 새로고침: 인기 줄과 최신 글을 함께 다시 받는다
  Future<void> _refresh() async {
    ref.invalidate(talkPopularProvider(_categoryValue));
    await ref
        .read(talkFeedControllerProvider(_categoryValue).notifier)
        .refresh();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final space = context.space;

    return Scaffold(
      backgroundColor: colors.background,
      body: SafeArea(
        child: Column(
          children: [
            _Header(onWritePressed: _openShare),
            SizedBox(height: space.sm.h),
            TalkCategoryChips(
              selectedCategory: _selectedCategory,
              onSelected: _onCategorySelected,
            ),
            SizedBox(height: space.sm.h),
            Expanded(child: _body()),
          ],
        ),
      ),
    );
  }

  Widget _body() {
    final feed = ref.watch(talkFeedControllerProvider(_categoryValue));
    final controller = ref.read(
      talkFeedControllerProvider(_categoryValue).notifier,
    );

    return switch (feed) {
      AsyncData(value: final state) when state.items.isEmpty =>
        RefreshIndicator(
          onRefresh: _refresh,
          child: CustomScrollView(
            controller: _scrollController,
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              SliverFillRemaining(
                hasScrollBody: false,
                child: Center(child: _EmptyBody(onSharePressed: _openShare)),
              ),
            ],
          ),
        ),
      AsyncData(value: final state) => RefreshIndicator(
        onRefresh: _refresh,
        child: _list(state, controller),
      ),
      AsyncError(:final error) => ElumStateBody(
        child: ElumErrorView.failure(
          error,
          fallback: context.l10n.talkFeedFailed,
          fallbackCode: 'E-TALK-001',
          onRetry: controller.refresh,
        ),
      ),
      _ => const ElumStateBody.loading(),
    };
  }

  Widget _list(TalkFeedState state, TalkFeedController controller) {
    final space = context.space;
    // 인기 줄: 받는 중·실패·0건이면 자리째 숨김
    final popularPosts = switch (ref.watch(
      talkPopularProvider(_categoryValue),
    )) {
      AsyncData(value: final posts) => posts,
      _ => const <TalkPostSummary>[],
    };

    return ListView(
      controller: _scrollController,
      physics: const AlwaysScrollableScrollPhysics(),
      padding: EdgeInsets.only(bottom: space.xl.h),
      children: [
        if (popularPosts.isNotEmpty) ...[
          TalkPopularRow(posts: popularPosts, onPostTapped: _openPost),
          SizedBox(height: _sectionGap.h),
        ],
        Padding(
          padding: EdgeInsets.symmetric(horizontal: space.screenH.w),
          child: Text(
            context.l10n.talkLatestTitle,
            style: context.typo.cardTitle.copyWith(
              color: context.colors.textPrimary,
            ),
          ),
        ),
        SizedBox(height: space.sm.h),
        for (final post in state.items)
          Padding(
            padding: EdgeInsets.fromLTRB(
              space.screenH.w,
              0,
              space.screenH.w,
              _cardGap.h,
            ),
            child: TalkPostCard(
              key: ValueKey(post.id),
              post: post,
              onTap: () => _openPost(post),
              onImportPressed: () => showTalkImportSheet(context, ref, post),
            ),
          ),
        if (state.isLoadingMore)
          Padding(
            padding: EdgeInsets.only(top: space.xs.h),
            child: Center(
              child: ElumSpinner(
                size: 24.w,
                color: context.colors.creditHistoryMutedText,
              ),
            ),
          ),
        if (state.hasLoadMoreFailed)
          _LoadMoreRetryRow(onTap: controller.retryLoadMore),
      ],
    );
  }
}

/// 제목 줄: 이야기 | + 올리기
class _Header extends StatelessWidget {
  const _Header({required this.onWritePressed});

  final VoidCallback onWritePressed;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final space = context.space;

    return Padding(
      padding: EdgeInsets.fromLTRB(
        space.screenH.w,
        space.sm.h,
        space.screenH.w,
        0,
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              context.l10n.talkTitle,
              style: context.typo.greeting.copyWith(color: colors.textPrimary),
            ),
          ),
          AppPressable(
            onTap: onWritePressed,
            child: Container(
              padding: EdgeInsets.symmetric(
                horizontal: space.sm.w,
                vertical: space.xs.h,
              ),
              decoration: BoxDecoration(
                color: colors.buttonEnabled,
                borderRadius: BorderRadius.circular(space.buttonRadius.r),
              ),
              child: Text(
                context.l10n.talkWriteButton,
                style: context.typo.chipLabel.copyWith(
                  color: colors.buttonEnabledText,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 글이 0건일 때: 루미 그림 + 안내 + 올리기 버튼 (받는 중·실패와 다른 화면)
class _EmptyBody extends StatelessWidget {
  const _EmptyBody({required this.onSharePressed});

  final VoidCallback onSharePressed;

  static const _illustrationSize = 200.0;

  @override
  Widget build(BuildContext context) {
    final space = context.space;
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: space.screenH.w),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Image.asset(
            AppAssets.storiesComingSoonLumi,
            width: _illustrationSize.w,
            height: _illustrationSize.w,
            fit: BoxFit.contain,
            // 장식 그림 (제목이 뜻을 전한다)
            excludeFromSemantics: true,
          ),
          SizedBox(height: space.md.h),
          Text(
            context.l10n.talkEmptyTitle,
            textAlign: TextAlign.center,
            style: context.typo.sectionTitle.copyWith(
              color: context.colors.textPrimary,
            ),
          ),
          SizedBox(height: space.lg.h),
          ElumButton(
            label: context.l10n.talkEmptyAction,
            onPressed: onSharePressed,
          ),
        ],
      ),
    );
  }
}

/// 목록 끝: 다음 쪽 받기 실패 시 다시 시도 줄
class _LoadMoreRetryRow extends StatelessWidget {
  const _LoadMoreRetryRow({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final space = context.space;
    return AppPressable(
      onTap: onTap,
      scaleDown: AppPressable.scaleCard,
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: space.screenH.w,
          vertical: space.md.h,
        ),
        child: Center(
          child: Text(
            context.l10n.talkLoadMoreRetry,
            textAlign: TextAlign.center,
            style: context.typo.tileLabel.copyWith(
              color: context.colors.textSecondary,
            ),
          ),
        ),
      ),
    );
  }
}
