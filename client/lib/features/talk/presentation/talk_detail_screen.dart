import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';

import '../../../core/assets/app_assets.dart';
import '../../../core/l10n/l10n_context.dart';
import '../../../core/network/app_failure.dart';
import '../../../core/network/server_error_code.dart';
import '../../../core/router/pop_or_home.dart';
import '../../../core/router/routes.dart';
import '../../../core/theme/theme_context_ext.dart';
import '../../../core/widgets/app_pressable.dart';
import '../../../core/widgets/elum_button.dart';
import '../../../core/widgets/elum_centered_title_row.dart';
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
import 'widgets/talk_import_sheet.dart';

/// 이야기 글 상세: 머리(뒤로 · 제목 · ⋯) > 본문 + 댓글 스크롤 > 댓글 입력 > 하단 고정 "내 일과로 가져오기"
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
  static const _sectionGap = 24.0;

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
    final post = detail.value;

    return Scaffold(
      backgroundColor: context.colors.background,
      body: SafeArea(
        child: Column(
          children: [
            _Header(
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
            if (post != null) ...[
              TalkCommentInput(onSubmit: _actions.sendComment),
              _ImportBar(post: post),
            ],
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
            ),
            SizedBox(height: _sectionGap.h),
            TalkCommentList(
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

/// 머리 줄: 뒤로 | 이야기 | ⋯ (글을 받기 전에는 ⋯ 없음)
class _Header extends StatelessWidget {
  const _Header({required this.onMorePressed});

  final VoidCallback? onMorePressed;

  static const _tapSize = 44.0;
  static const _iconSize = 24.0;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final space = context.space;
    final l10n = context.l10n;

    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: space.xs.w,
        vertical: space.xs.h,
      ),
      child: ElumCenteredTitleRow(
        sideSlotWidth: _tapSize.w,
        leading: Semantics(
          button: true,
          label: l10n.commonBack,
          child: AppPressable(
            onTap: context.popOrHome,
            scaleDown: AppPressable.scaleIcon,
            child: SizedBox(
              width: _tapSize.w,
              height: _tapSize.w,
              child: Center(
                child: SvgPicture.asset(
                  AppAssets.iconBack,
                  width: _iconSize.w,
                  height: _iconSize.w,
                  excludeFromSemantics: true,
                ),
              ),
            ),
          ),
        ),
        title: Text(
          l10n.talkTitle,
          textAlign: TextAlign.center,
          style: context.typo.navTitle.copyWith(color: colors.textPrimary),
        ),
        trailing: SizedBox(
          width: _tapSize.w,
          height: _tapSize.w,
          child: onMorePressed == null
              ? null
              : AppPressable(
                  onTap: onMorePressed,
                  scaleDown: AppPressable.scaleIcon,
                  semanticLabel: l10n.talkMoreLabel,
                  child: Icon(
                    Icons.more_horiz_rounded,
                    size: _iconSize.w,
                    color: colors.textPrimary,
                  ),
                ),
        ),
      ),
    );
  }
}

/// 내려간 글: 안내 + 돌아가기
class _GoneBody extends StatelessWidget {
  const _GoneBody({required this.onBackPressed});

  final VoidCallback onBackPressed;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final space = context.space;
    return ElumStateBody(
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: space.screenH.w),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              l10n.talkPostGoneTitle,
              textAlign: TextAlign.center,
              style: context.typo.sectionTitle.copyWith(
                color: context.colors.textPrimary,
              ),
            ),
            SizedBox(height: space.lg.h),
            ElumButton(label: l10n.talkPostGoneBack, onPressed: onBackPressed),
          ],
        ),
      ),
    );
  }
}

/// 하단 고정 버튼: 내 일과로 가져오기 (이미 가져왔으면 "✓ 일과관리에 넣었어요", 다시 누르면 한 번 더)
/// 키보드가 올라와 있으면 입력줄을 가리지 않게 감춘다
class _ImportBar extends ConsumerWidget {
  const _ImportBar({required this.post});

  final TalkPostDetail post;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isKeyboardOpen = MediaQuery.viewInsetsOf(context).bottom > 0;
    if (isKeyboardOpen) return const SizedBox.shrink();

    final l10n = context.l10n;
    final space = context.space;
    return Padding(
      padding: EdgeInsets.fromLTRB(
        space.screenH.w,
        space.xs.h,
        space.screenH.w,
        space.sm.h,
      ),
      child: ElumButton(
        label: post.isImportedByMe
            ? l10n.talkImportedButton
            : l10n.talkImportButton,
        onPressed: () => showTalkImportSheet(context, ref, post.toSummary()),
      ),
    );
  }
}
