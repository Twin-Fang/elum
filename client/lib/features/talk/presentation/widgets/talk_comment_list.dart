import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../core/l10n/date_labels.dart';
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
import 'talk_empty_message.dart';
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

  /// 댓글 사이 가는 선 (웜그레이 1)
  static const _dividerHeight = 1.0;

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
              TalkEmptyMessage(title: l10n.talkCommentsEmpty, isInPanel: true),
            AsyncData(value: final state) => Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (var index = 0; index < state.items.length; index++) ...[
                  if (index > 0)
                    Container(
                      height: _dividerHeight,
                      color: context.colors.talkSectionDivider,
                    ),
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

/// 댓글 한 줄: 이름 · 시각 + ⋯ > 내용 (⋯ 버튼이나 길게 누르면 메뉴)
class _CommentRow extends StatelessWidget {
  const _CommentRow({required this.comment, required this.onMenuRequested});

  final TalkComment comment;
  final VoidCallback onMenuRequested;

  /// 줄 위아래 · 이름 > 시각 · 머리 > 내용 (⋯ 누름 영역 44 가 머리 줄 높이를 정하므로 위는 덜 띄운다)
  static const _padTop = 6.0;
  static const _padBottom = 16.0;
  static const _nameToTime = 8.0;
  static const _headerToBody = 2.0;

  /// ⋯ 누름 영역(44)에서 아이콘(18) 오른쪽 남는 폭 (44 - 18) / 2
  static const _dotsOverhang = 13.0;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colors = context.colors;
    final typo = context.typo;

    // 가린 댓글은 지우기·신고 메뉴가 의미 없어 ⋯ 와 길게 누르기를 뺀다
    final isHidden = comment.isHidden;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onLongPress: isHidden ? null : onMenuRequested,
      child: Padding(
        padding: EdgeInsets.only(top: _padTop.h, bottom: _padBottom.h),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                // 이름 · 시각은 남은 폭 안에서, ⋯ 는 오른쪽 끝에
                Expanded(
                  child: Row(
                    children: [
                      Flexible(
                        child: Text(
                          comment.authorNickname ?? l10n.talkAuthorFallback,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: typo.talkFormLabel.copyWith(
                            color: colors.textPrimary,
                          ),
                        ),
                      ),
                      SizedBox(width: _nameToTime.w),
                      Text(
                        l10n.timeAgoOf(comment.createdAt, DateTime.now()),
                        style: typo.talkMeta.copyWith(
                          color: colors.talkMetaText,
                        ),
                      ),
                    ],
                  ),
                ),
                // 누름 영역 44 중 아이콘(18) 오른쪽 끝을 본문 끝선에 맞춘다
                if (!isHidden)
                  Transform.translate(
                    offset: Offset(_dotsOverhang.w, 0),
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
