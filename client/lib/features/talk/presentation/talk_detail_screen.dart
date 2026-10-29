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
import '../../../core/widgets/elum_text_link.dart';
import '../../../core/widgets/elum_pull_to_refresh.dart';
import '../application/talk_comment_controller.dart';
import '../application/talk_detail_controller.dart';
import '../domain/talk_post.dart';
import '../domain/talk_screen_codes.dart';
import 'talk_detail_actions.dart';
import 'widgets/talk_comment_input.dart';
import 'widgets/talk_comment_list.dart';
import 'widgets/talk_detail_body.dart';
import 'widgets/talk_empty_line.dart';
import 'widgets/talk_import_sheet.dart';
import 'widgets/talk_top_bar.dart';

/// 이야기 글 상세: 머리(뒤로 · 제목 · 신고 또는 ⋯ · 공유) > 본문(카드 · 가져오기) + 댓글 스크롤 > 하단 고정 댓글 입력
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

  /// 도움돼요 칩 > 구분 띠 16 · 띠 높이 7 · 띠 > 댓글 머리 16 (시안 1813:7718 · 1783:7172 실측, 칩·머리 줄 높이 1.0)
  static const _bodyToDivider = 16.0;
  static const _dividerHeight = 7.0;
  static const _dividerToComments = 16.0;

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

  /// 지금 보이는 글이 링크 글인가 (댓글을 받지 않는다)
  bool get _isLinkOnlyPost =>
      ref.read(talkDetailControllerProvider(widget.postId)).value?.isLinkOnly ??
      false;

  void _loadMoreCommentsNearEnd() {
    if (_isLinkOnlyPost) return;
    if (_scrollController.position.extentAfter < _loadMoreExtent) {
      ref
          .read(talkCommentControllerProvider(widget.postId).notifier)
          .loadMore();
    }
  }

  /// 당겨서 새로고침: 글 > 댓글 첫 쪽 순서로 다시 받는다 (앱 복귀 시 자동 갱신은 하지 않음)
  /// 글이 내려갔으면 댓글은 받지 않고, 실패하면 보던 내용은 두고 실패 팝업만 띄운다 ([ElumPullToRefresh])
  Future<void> _refresh() async {
    await ref
        .read(talkDetailControllerProvider(widget.postId).notifier)
        .refresh();
    if (!ref.read(talkDetailControllerProvider(widget.postId)).hasValue ||
        _isLinkOnlyPost) {
      return;
    }
    await ref
        .read(talkCommentControllerProvider(widget.postId).notifier)
        .refresh();
  }

  /// 머리 ⋯·신고: 남의 글은 늘, 내 글은 공개 글만 (내 링크 글은 일과관리에서 끈다)
  bool _isMoreVisible(TalkPostDetail? post) =>
      post != null && (!post.isMine || !post.isLinkOnly);

  /// 공유 아이콘: 공개 글은 늘, 링크 글은 보낸 사람만 (받은 사람이 다시 퍼뜨리지 않게)
  bool _isShareVisible(TalkPostDetail? post) =>
      post != null && (!post.isLinkOnly || post.isMine);

  /// 글이 내려갔는가 (없는 글·내가 내린 글·꺼진 링크)
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
              title: post != null && post.isLinkOnly
                  ? context.l10n.talkLinkReceivedTitle
                  : context.l10n.talkTitle,
              onBackPressed: context.popOrHome,
              isMoreVisible: _isMoreVisible(post),
              // 남의 글은 신고 깃발(신고 · 숨기기), 내 글은 ⋯(고치기 · 내리기)
              shouldShowReportIcon: post != null && !post.isMine,
              onMorePressed: post == null
                  ? null
                  : () => _actions.openPostMenu(post),
              onSharePressed: _isShareVisible(post)
                  ? (origin) => _actions.shareLink(post!, origin)
                  : null,
            ),
            Expanded(
              child: switch (detail) {
                AsyncData(value: final post) => _content(post),
                AsyncError(:final error) when _isPostGone(error) => _GoneBody(
                  errorCode: AppFailure.of(
                    error,
                  ).badgeOr(TalkScreenCodes.detail),
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
            // 링크 글은 댓글이 없다
            if (post != null && !post.isLinkOnly)
              TalkCommentInput(onSubmit: _actions.sendComment),
          ],
        ),
      ),
    );
  }

  Widget _content(TalkPostDetail post) {
    final space = context.space;
    return ElumPullToRefresh(
      onRefresh: _refresh,
      failureMessage: context.l10n.talkDetailLoadFailed,
      failureCode: TalkScreenCodes.detail,
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
            // 링크 글은 도움돼요·댓글이 없어 본문에서 끝난다
            if (!post.isLinkOnly) ..._commentSection(post),
          ],
        ),
      ),
    );
  }

  /// 구분 띠 > 댓글 목록 (공개 글만)
  List<Widget> _commentSection(TalkPostDetail post) {
    final comments = ref.watch(talkCommentControllerProvider(widget.postId));
    return [
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
    ];
  }
}

/// 내려간 글 (빈 상태 결): 본문 첫 줄 자리에 웜그레이 글 줄 > `이야기로 돌아가기` 글자 버튼
class _GoneBody extends StatelessWidget {
  const _GoneBody({required this.errorCode, required this.onBackPressed});

  /// 제보용 에러 코드 (서버 코드가 있으면 그것)
  final String errorCode;
  final VoidCallback onBackPressed;

  /// 머리 줄 > 글 줄 (본문 머리 > 칩과 같은 20) · 글 줄 > 돌아가기
  static const _headerToLine = 20.0;
  static const _lineToLink = 16.0;

  /// 글 줄 좌우 (판 x=16)
  static const _lineInset = 16.0;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(
        _lineInset.w,
        _headerToLine.h,
        _lineInset.w,
        0,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TalkEmptyLine(title: l10n.talkPostGoneTitle),
          SizedBox(height: _lineToLink.h),
          Center(
            child: ElumTextLink(
              label: l10n.talkPostGoneBack,
              onTap: onBackPressed,
            ),
          ),
          SizedBox(height: _lineToLink.h),
          Center(
            child: Text(
              errorCode,
              // 에러 화면 코드 줄과 같은 결
              style: context.typo.promptBody.copyWith(
                color: context.colors.promptMuted,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
