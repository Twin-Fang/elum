import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../core/l10n/l10n_context.dart';
import '../../../../core/theme/app_motion.dart';
import '../../../../core/theme/theme_context_ext.dart';
import '../../../../core/widgets/app_fade_slide_in.dart';
import '../../../../core/widgets/app_pressable.dart';
import '../../../../core/widgets/elum_error_view.dart';
import '../../../../core/widgets/elum_spinner.dart';
import '../../application/talk_comment_controller.dart';
import '../../domain/talk_comment.dart';
import '../../domain/talk_screen_codes.dart';
import 'talk_detail_parts.dart';
import 'talk_top_bar.dart';

/// 댓글 영역(스크롤 안에 이어 붙이는 조각): 머리 `댓글  N` > 댓글(오래된 순) > 끝 상태(받는 중·재시도)
/// 빈 상태·첫 쪽 실패도 여기서 그린다. 댓글 ⋯ 버튼이나 길게 누르기로 [onCommentMenuRequested]
class TalkCommentList extends StatelessWidget {
  const TalkCommentList({
    super.key,
    required this.commentCount,
    required this.comments,
    required this.onCommentMenuRequested,
    required this.onRetryPressed,
    required this.onRetryLoadMorePressed,
  });

  /// 머리 숫자. 목록을 못 받아도 보이게 글 응답의 댓글 수를 쓴다
  final int commentCount;
  final AsyncValue<TalkCommentState> comments;

  /// 머리 `댓글` > 숫자 (시안 8)
  static const _titleToCount = 8.0;

  /// 댓글 칸 좌우 · 머리 글자가 칸보다 더 들어가는 폭 · 머리 > 첫 칸 · 칸 사이 (시안 16 · 8 · 16 · 8)
  static const _cardInset = 16.0;
  static const _headerInset = 8.0;
  static const _headerToComments = 16.0;
  static const _commentGap = 8.0;

  /// 차례로 떠오르는 댓글 수 상한
  static const _maxStaggerCount = 6;
  final ValueChanged<TalkComment> onCommentMenuRequested;

  /// 첫 쪽 받기 실패 줄을 눌렀을 때
  final VoidCallback onRetryPressed;

  /// 다음 쪽 받기 실패 줄을 눌렀을 때
  final VoidCallback onRetryLoadMorePressed;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final space = context.space;
    final headerStyle = context.typo.talkCommentsHeader.copyWith(
      color: context.colors.talkMetaText,
    );

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: _cardInset.w),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 머리 `댓글  3` (시안 1830:7916 · 1830:7917, 글자는 화면 여백 24 줄)
          Padding(
            padding: EdgeInsets.symmetric(horizontal: _headerInset.w),
            child: Row(
              children: [
                Text(l10n.talkCommentsTitle, style: headerStyle),
                SizedBox(width: _titleToCount.w),
                Text('$commentCount', style: headerStyle),
              ],
            ),
          ),
          SizedBox(height: _headerToComments.h),
          switch (comments) {
            AsyncData(value: final state) when state.items.isEmpty =>
              _MessageLine(text: l10n.talkCommentsEmpty),
            AsyncData(value: final state) => Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (var index = 0; index < state.items.length; index++) ...[
                  if (index > 0) SizedBox(height: _commentGap.h),
                  // 첫 화면 댓글만 차례로 떠오른다 (뒤 쪽은 기다리지 않게 늦춤 상한)
                  AppFadeSlideIn(
                    key: ValueKey(state.items[index].id),
                    offset: 8,
                    delay: Duration(
                      milliseconds:
                          AppMotion.staggerDelayMs *
                          (index < _maxStaggerCount ? index : _maxStaggerCount),
                    ),
                    child: _CommentRow(
                      comment: state.items[index],
                      onMenuRequested: () =>
                          onCommentMenuRequested(state.items[index]),
                    ),
                  ),
                ],
                if (state.isLoadingMore)
                  Padding(
                    padding: EdgeInsets.symmetric(vertical: space.sm.h),
                    child: Center(
                      child: ElumSpinner(
                        size: 24.w,
                        color: context.colors.talkMetaIcon,
                      ),
                    ),
                  ),
                if (state.hasLoadMoreFailed)
                  _MessageLine(
                    text: l10n.talkLoadMoreRetry,
                    onTap: onRetryLoadMorePressed,
                  ),
              ],
            ),
            AsyncError(:final error) => ElumErrorView.failure(
              error,
              fallback: l10n.talkCommentsFailed,
              fallbackCode: TalkScreenCodes.comment,
              onRetry: onRetryPressed,
              compact: true,
            ),
            _ => Padding(
              padding: EdgeInsets.symmetric(vertical: space.md.h),
              child: Center(
                child: ElumSpinner(
                  size: 24.w,
                  color: context.colors.talkMetaIcon,
                ),
              ),
            ),
          },
        ],
      ),
    );
  }
}

/// 댓글 칸: 이름 | 날짜 시각 + ⋯ > 내용 (시안 1860:7944, ⋯ 버튼이나 길게 누르면 메뉴)
/// 이름 뒤 표시 2개: 글쓴이 댓글 (글쓴이), 내 댓글 (나) + 민트 이름
class _CommentRow extends StatelessWidget {
  const _CommentRow({required this.comment, required this.onMenuRequested});

  final TalkComment comment;
  final VoidCallback onMenuRequested;

  /// 칸 안쪽 · 아래 · 머리 > 내용 (시안 16 · 15 · 8)
  static const _padding = 16.0;
  static const _padBottom = 15.0;
  static const _headerToBody = 8.0;

  /// ⋯ 누름 영역(44) 중심을 머리 줄(12) 중심에 맞추고 아이콘(18) 오른쪽 끝을 칸 안쪽 선에 맞춘다
  static const _dotsTop = -16.0;
  static const _dotsRight = -13.0;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colors = context.colors;
    final typo = context.typo;

    // 가린 댓글은 지우기·신고 메뉴가 의미 없어 ⋯ 와 길게 누르기를 뺀다
    final isHidden = comment.isHidden;
    final name = comment.authorNickname ?? l10n.talkAuthorFallback;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onLongPress: isHidden ? null : onMenuRequested,
      child: Container(
        padding: EdgeInsets.fromLTRB(
          _padding.w,
          _padding.h,
          _padding.w,
          _padBottom.h,
        ),
        decoration: BoxDecoration(
          color: colors.talkCommentFill,
          borderRadius: BorderRadius.circular(context.space.cardRadius.r),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                Padding(
                  // ⋯ 자리만큼 이름 줄을 비운다
                  padding: EdgeInsets.only(right: isHidden ? 0 : _padding.w),
                  child: TalkDetailPostedRow(
                    authorName: comment.isMine
                        ? l10n.talkCommentAuthorMine(name)
                        : comment.isPostAuthor
                        ? l10n.talkCommentAuthorPostWriter(name)
                        : name,
                    authorColor: comment.isMine
                        ? colors.talkCommentMineName
                        : null,
                    createdAt: comment.createdAt,
                  ),
                ),
                if (!isHidden)
                  Positioned(
                    top: _dotsTop.w,
                    right: _dotsRight.w,
                    child: TalkMoreDotsButton(onTap: onMenuRequested),
                  ),
              ],
            ),
            SizedBox(height: _headerToBody.h),
            Text(
              isHidden ? l10n.talkCommentHiddenNotice : comment.body,
              style: typo.talkCommentBody.copyWith(
                color: isHidden ? colors.talkMetaText : colors.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 안내 한 줄: 빈 상태·실패 (onTap 이 있으면 눌러서 다시 시도)
class _MessageLine extends StatelessWidget {
  const _MessageLine({required this.text, this.onTap});

  final String text;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final line = Padding(
      padding: EdgeInsets.symmetric(vertical: context.space.md.h),
      child: Center(
        child: Text(
          text,
          textAlign: TextAlign.center,
          style: context.typo.talkGuide.copyWith(
            color: context.colors.talkMetaText,
          ),
        ),
      ),
    );
    if (onTap == null) return line;
    return AppPressable(
      onTap: onTap,
      scaleDown: AppPressable.scaleCard,
      child: line,
    );
  }
}
