import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../core/l10n/date_labels.dart';
import '../../../../core/l10n/l10n_context.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/theme/theme_context_ext.dart';
import '../../../../core/widgets/app_pressable.dart';
import '../../../../core/widgets/elum_spinner.dart';
import '../../application/talk_comment_controller.dart';
import '../../domain/talk_comment.dart';

/// 댓글 영역(스크롤 안에 이어 붙이는 조각): 제목 > 댓글(오래된 순) > 끝 상태(받는 중·재시도)
/// 빈 상태·첫 쪽 실패도 여기서 그린다. 댓글을 길게 누르면 [onCommentLongPressed]
class TalkCommentList extends StatelessWidget {
  const TalkCommentList({
    super.key,
    required this.comments,
    required this.onCommentLongPressed,
    required this.onRetryPressed,
    required this.onRetryLoadMorePressed,
  });

  final AsyncValue<TalkCommentState> comments;
  final ValueChanged<TalkComment> onCommentLongPressed;

  /// 첫 쪽 받기 실패 줄을 눌렀을 때
  final VoidCallback onRetryPressed;

  /// 다음 쪽 받기 실패 줄을 눌렀을 때
  final VoidCallback onRetryLoadMorePressed;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final space = context.space;

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: space.screenH.w),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            l10n.talkCommentsTitle,
            style: context.typo.cardTitle.copyWith(
              color: context.colors.textPrimary,
            ),
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
                    onLongPress: () => onCommentLongPressed(comment),
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
            AsyncError() => _MessageLine(
              text: l10n.talkCommentsFailed,
              onTap: onRetryPressed,
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

/// 댓글 한 줄: 닉네임 · 시간 > 내용 (길게 누르면 메뉴)
class _CommentRow extends StatelessWidget {
  const _CommentRow({
    super.key,
    required this.comment,
    required this.onLongPress,
  });

  final TalkComment comment;
  final VoidCallback onLongPress;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colors = context.colors;
    final typo = context.typo;
    final space = context.space;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onLongPress: onLongPress,
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: space.xs.h),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${comment.authorNickname ?? l10n.talkAuthorFallback}'
              ' · ${l10n.timeAgoOf(comment.createdAt, DateTime.now())}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: typo.caption.copyWith(color: colors.textSecondary),
            ),
            SizedBox(height: space.xs.h / 2),
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
