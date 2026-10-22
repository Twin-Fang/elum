import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';

import '../../../core/l10n/l10n_context.dart';
import '../../../core/network/app_failure.dart';
import '../../../core/network/server_error_code.dart';
import '../../../core/router/pop_or_home.dart';
import '../../../core/router/routes.dart';
import '../../../core/theme/theme_context_ext.dart';
import '../../../core/widgets/elum_error_view.dart';
import '../../../core/widgets/elum_state_body.dart';
import '../../../core/widgets/show_failure.dart';
import '../application/talk_comment_controller.dart';
import '../application/talk_detail_controller.dart';
import '../domain/talk_post.dart';
import '../domain/talk_screen_codes.dart';
import 'talk_detail_actions.dart';
import 'widgets/talk_comment_input.dart';
import 'widgets/talk_comment_list.dart';
import 'widgets/talk_detail_body.dart';
import 'widgets/talk_empty_message.dart';
import 'widgets/talk_import_sheet.dart';
import 'widgets/talk_top_bar.dart';

/// 이야기 글 상세: 머리(뒤로 · 제목 · ⋯) > 본문(카드 · 가져오기) + 댓글 스크롤 > 하단 고정 댓글 입력
/// 상태: 받는 중 / 내려간 글(404) / 실패(다시 하기 + 에러 코드) / 본문
class TalkDetailScreen extends ConsumerStatefulWidget {
  const TalkDetailScreen({super.key, required this.postId});

  final String postId;

  @override
  ConsumerState<TalkDetailScreen> createState() => _TalkDetailScreenState();
}

class _TalkDetailScreenState extends ConsumerState<TalkDetailScreen> {
  final _scrollController = ScrollController();

  /// 끝까지 이만큼 남으면 다음 댓글 쪽을 받는다
  static const _loadMoreExtent = 320.0;

  /// 도움돼요 칩 > 구분 띠 15 · 띠 높이 7 · 띠 > 댓글 머리 14 (시안 1830:7918)
  static const _bodyToDivider = 15.0;
  static const _dividerHeight = 7.0;
  static const _dividerToComments = 14.0;

  late final _actions = TalkDetailActions(
    context: context,
    ref: ref,
    postId: widget.postId,
  );

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_loadMoreCommentsNearEnd);
  }

  @override
  void dispose() {
    _scrollController
      ..removeListener(_loadMoreCommentsNearEnd)
      ..dispose();
    super.dispose();
  }

  void _loadMoreCommentsNearEnd() {
    if (_scrollController.position.extentAfter < _loadMoreExtent) {
      ref
          .read(talkCommentControllerProvider(widget.postId).notifier)
          .loadMore();
    }
  }

  /// 당겨서 새로고침: 글 > 댓글 첫 쪽 순서로 다시 받는다 (앱 복귀 시 자동 갱신은 하지 않음)
  /// 글이 내려갔으면 댓글은 받지 않고, 실패하면 보던 내용은 두고 실패 팝업만 띄운다
  Future<void> _refresh() async {
    try {
      await ref
          .read(talkDetailControllerProvider(widget.postId).notifier)
          .refresh();
      if (!ref.read(talkDetailControllerProvider(widget.postId)).hasValue) {
        return;
      }
      await ref
          .read(talkCommentControllerProvider(widget.postId).notifier)
          .refresh();
    } catch (e) {
      if (!mounted) return;
      // 스피너가 팝업을 기다리지 않게 await 하지 않음
      unawaited(
        showFailure(
          context,
          e,
          fallback: context.l10n.talkDetailLoadFailed,
          fallbackCode: TalkScreenCodes.detail,
        ),
      );
    }
  }

  /// 글이 내려갔는가 (없는 글·내가 내린 글)
  bool _isPostGone(Object error) =>
      AppFailure.of(error).server?.code == ServerErrorCode.talkPostNotFound;

  @override
  Widget build(BuildContext context) {
    final detail = ref.watch(talkDetailControllerProvider(widget.postId));
    // 에러 상태(내려간 글 등)는 이전 값이 남아 있어도 메뉴·입력줄·가져오기를 숨김
    final post = detail.hasError ? null : detail.value;

    return Scaffold(
      backgroundColor: context.colors.background,
      // 위 안전영역은 머리 줄이 시안 y 로 직접 맞춘다
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            TalkTopBar(
              title: context.l10n.talkTitle,
              onBackPressed: context.popOrHome,
              isMoreVisible: post != null,
              onMorePressed: post == null
                  ? null
                  : () => _actions.openPostMenu(post),
            ),
            Expanded(
              child: switch (detail) {
                AsyncData(value: final post) => _content(post),
                AsyncError(:final error) when _isPostGone(error) => _GoneBody(
                  // 진입 경로와 무관하게 이야기 탭으로 이동
                  onBackPressed: () => context.go(Routes.guardianTalk),
                ),
                AsyncError(:final error) => ElumStateBody(
                  child: ElumErrorView.failure(
                    error,
                    fallback: context.l10n.talkDetailLoadFailed,
                    fallbackCode: TalkScreenCodes.detail,
                    onRetry: () => ref.invalidate(
                      talkDetailControllerProvider(widget.postId),
                    ),
                  ),
                ),
                _ => const ElumStateBody.loading(),
              },
            ),
            if (post != null) TalkCommentInput(onSubmit: _actions.sendComment),
          ],
        ),
      ),
    );
  }

  Widget _content(TalkPostDetail post) {
    final space = context.space;
    final comments = ref.watch(talkCommentControllerProvider(widget.postId));
    return RefreshIndicator(
      onRefresh: _refresh,
      child: SingleChildScrollView(
        controller: _scrollController,
        physics: const AlwaysScrollableScrollPhysics(),
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        padding: EdgeInsets.only(bottom: space.lg.h),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TalkDetailBody(
              post: post,
              onHelpfulPressed: _actions.toggleHelpful,
              onImportPressed: () =>
                  showTalkImportSheet(context, ref, post.toSummary()),
            ),
            SizedBox(height: _bodyToDivider.h),
            Container(
              height: _dividerHeight.h,
              color: context.colors.talkSectionDivider,
            ),
            SizedBox(height: _dividerToComments.h),
            TalkCommentList(
              commentCount: post.commentCount,
              comments: comments,
              onCommentMenuRequested: _actions.openCommentMenu,
              onRetryPressed: () =>
                  ref.invalidate(talkCommentControllerProvider(widget.postId)),
              onRetryLoadMorePressed: ref
                  .read(talkCommentControllerProvider(widget.postId).notifier)
                  .retryLoadMore,
            ),
          ],
        ),
      ),
    );
  }
}

/// 내려간 글: 안내 + 이야기로 돌아가기
class _GoneBody extends StatelessWidget {
  const _GoneBody({required this.onBackPressed});

  final VoidCallback onBackPressed;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return ElumStateBody(
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: context.space.screenH.w),
        child: TalkEmptyMessage(
          title: l10n.talkPostGoneTitle,
          actionLabel: l10n.talkPostGoneBack,
          onActionPressed: onBackPressed,
        ),
      ),
    );
  }
}
