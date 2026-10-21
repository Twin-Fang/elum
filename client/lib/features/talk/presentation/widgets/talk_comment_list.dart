import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../core/l10n/date_labels.dart';
import '../../../../core/l10n/l10n_context.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/theme/theme_context_ext.dart';
import '../../../../core/widgets/app_pressable.dart';
import '../../../../core/widgets/min_tap_target.dart';
import '../../../../core/widgets/elum_error_view.dart';
import '../../../../core/widgets/elum_spinner.dart';
import '../../application/talk_comment_controller.dart';
import '../../domain/talk_comment.dart';
import '../../domain/talk_screen_codes.dart';

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
      padding: EdgeInsets.symmetric(horizontal: space.screenH.w),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 머리 `댓글  3` (시안 1830:7916 · 1830:7917)
          Row(
            children: [
              Text(l10n.talkCommentsTitle, style: headerStyle),
              SizedBox(width: _titleToCount.w),
              Text('$commentCount', style: headerStyle),
            ],
          ),
          SizedBox(height: space.sm.h),
          switch (comments) {
            AsyncData(value: final state) when state.items.isEmpty =>
              _MessageLine(text: l10n.talkCommentsEmpty),
            AsyncData(value: final state) => Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final comment in state.items)
                  _CommentRow(
                    key: ValueKey(comment.id),
                    comment: comment,
                    onMenuRequested: () => onCommentMenuRequested(comment),
                  ),
                if (state.isLoadingMore)
                  Padding(
                    padding: EdgeInsets.symmetric(vertical: space.sm.h),
                    child: Center(
                      child: ElumSpinner(
                        size: 24.w,
                        color: context.colors.creditHistoryMutedText,
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
                  color: context.colors.creditHistoryMutedText,
                ),
              ),
            ),
          },
        ],
      ),
    );
  }
}

/// 댓글 한 줄: 닉네임 · 시간 + ⋯ > 내용 (⋯ 버튼이나 길게 누르면 메뉴)
class _CommentRow extends StatelessWidget {
  const _CommentRow({
    super.key,
    required this.comment,
    required this.onMenuRequested,
  });

  final TalkComment comment;
  final VoidCallback onMenuRequested;

  static const _moreIconSize = 20.0;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colors = context.colors;
    final typo = context.typo;
    final space = context.space;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onLongPress: onMenuRequested,
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: space.xs.h / 2),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    '${comment.authorNickname ?? l10n.talkAuthorFallback}'
                    ' · ${l10n.timeAgoOf(comment.createdAt, DateTime.now())}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: typo.caption.copyWith(color: colors.textSecondary),
                  ),
                ),
                AppPressable(
                  onTap: onMenuRequested,
                  scaleDown: AppPressable.scaleIcon,
                  semanticLabel: l10n.talkMoreLabel,
                  child: MinTapTarget(
                    child: Icon(
                      Icons.more_horiz_rounded,
                      size: _moreIconSize.w,
                      color: colors.textSecondary,
                    ),
                  ),
                ),
              ],
            ),
            Text(
              comment.body,
              style: typo.body.paragraph.copyWith(color: colors.textPrimary),
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
          style: context.typo.tileLabel.copyWith(
            color: context.colors.textSecondary,
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
