import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../core/l10n/date_labels.dart';
import '../../../../core/l10n/l10n_context.dart';
import '../../../../core/theme/theme_context_ext.dart';
import '../../../../core/widgets/app_pressable.dart';
import '../../domain/talk_post.dart';
import 'talk_step_image.dart';

/// 피드 글 카드: 닉네임 · 시간 · 분류 > 제목 > 카드 그림 4장(+N) > 한마디 > 도움돼요 · 댓글 · 내 일과로
class TalkPostCard extends StatelessWidget {
  const TalkPostCard({
    super.key,
    required this.post,
    required this.onTap,
    required this.onImportPressed,
  });

  final TalkPostSummary post;
  final VoidCallback onTap;
  final VoidCallback onImportPressed;

  /// 카드에 그림으로 보이는 최대 장수
  static const _maxVisibleSteps = 4;
  static const _padding = 16.0;
  static const _imageRadius = 12.0;
  static const _imageGap = 6.0;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typo = context.typo;
    final space = context.space;
    final l10n = context.l10n;
    final note = post.note;
    final category = post.category;
    final visibleSteps = post.previewSteps.take(_maxVisibleSteps).toList();
    final hiddenStepCount = post.stepCount - visibleSteps.length;

    return AppPressable(
      onTap: onTap,
      scaleDown: AppPressable.scaleCard,
      child: Container(
        padding: EdgeInsets.all(_padding.w),
        decoration: BoxDecoration(
          color: colors.creditCardBg,
          borderRadius: BorderRadius.circular(space.cardRadius.r),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 닉네임 · 시간 · 분류 배지
            Row(
              children: [
                Expanded(
                  child: Text(
                    '${post.authorNickname ?? l10n.talkAuthorFallback}'
                    ' · ${l10n.timeAgoOf(post.createdAt, DateTime.now())}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: typo.caption.copyWith(color: colors.textSecondary),
                  ),
                ),
                if (category != null) ...[
                  SizedBox(width: space.xs.w),
                  _CategoryBadge(label: category.labelOf(l10n)),
                ],
              ],
            ),
            SizedBox(height: space.sm.h),
            Text(
              post.title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: typo.cardTitle.copyWith(
                color: colors.textPrimary,
                height: 1.3,
              ),
            ),
            if (visibleSteps.isNotEmpty) ...[
              SizedBox(height: space.sm.h),
              _StepImageRow(
                postId: post.id,
                steps: visibleSteps,
                hiddenStepCount: hiddenStepCount,
                imageGap: _imageGap.w,
                imageRadius: _imageRadius.r,
                maxVisibleSteps: _maxVisibleSteps,
              ),
            ],
            // 한마디 한 줄
            if (note != null && note.isNotEmpty) ...[
              SizedBox(height: space.sm.h),
              Text.rich(
                TextSpan(
                  children: [
                    TextSpan(
                      text: l10n.talkNoteLabel,
                      style: typo.tileLabel.copyWith(
                        color: colors.textPrimary,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    TextSpan(
                      text: '  $note',
                      style: typo.tileLabel.copyWith(
                        color: colors.textSecondary,
                      ),
                    ),
                  ],
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
            SizedBox(height: space.sm.h),
            // 도움돼요 · 댓글 · 내 일과로
            Row(
              children: [
                Text(
                  l10n.talkHelpfulCount(post.helpfulCount),
                  style: typo.caption.copyWith(color: colors.textSecondary),
                ),
                SizedBox(width: space.sm.w),
                Text(
                  l10n.talkCommentCount(post.commentCount),
                  style: typo.caption.copyWith(color: colors.textSecondary),
                ),
                const Spacer(),
                _ImportButton(onPressed: onImportPressed),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _CategoryBadge extends StatelessWidget {
  const _CategoryBadge({required this.label});

  final String label;

  static const _paddingH = 8.0;
  static const _paddingV = 4.0;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: _paddingH.w,
        vertical: _paddingV.h,
      ),
      decoration: BoxDecoration(
        color: colors.editChipBg,
        borderRadius: BorderRadius.circular(context.space.cardRadius.r),
      ),
      child: Text(
        label,
        maxLines: 1,
        style: context.typo.caption.copyWith(color: colors.textPrimary),
      ),
    );
  }
}

/// 카드 그림 줄: 정사각 4칸, 카드가 더 있으면 마지막 칸 위에 "+N"
/// 4칸 폭을 항상 같게 유지하려고 부족한 칸은 빈 자리로 채운다
class _StepImageRow extends StatelessWidget {
  const _StepImageRow({
    required this.postId,
    required this.steps,
    required this.hiddenStepCount,
    required this.imageGap,
    required this.imageRadius,
    required this.maxVisibleSteps,
  });

  final String postId;
  final List<TalkStep> steps;
  final int hiddenStepCount;
  final double imageGap;
  final double imageRadius;
  final int maxVisibleSteps;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Row(
      children: [
        for (var index = 0; index < maxVisibleSteps; index++) ...[
          if (index > 0) SizedBox(width: imageGap),
          Expanded(
            child: index >= steps.length
                ? const SizedBox.shrink()
                : AspectRatio(
                    aspectRatio: 1,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(imageRadius),
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          TalkStepImage(postId: postId, step: steps[index]),
                          // 남은 카드 수
                          if (index == maxVisibleSteps - 1 &&
                              hiddenStepCount > 0)
                            ColoredBox(
                              color: colors.sheetScrim,
                              child: Center(
                                child: Text(
                                  '+$hiddenStepCount',
                                  style: context.typo.sectionTitle.copyWith(
                                    color: colors.surface,
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
          ),
        ],
      ],
    );
  }
}

class _ImportButton extends StatelessWidget {
  const _ImportButton({required this.onPressed});

  final VoidCallback onPressed;

  static const _paddingH = 14.0;
  static const _paddingV = 8.0;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return AppPressable(
      onTap: onPressed,
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: _paddingH.w,
          vertical: _paddingV.h,
        ),
        decoration: BoxDecoration(
          color: colors.buttonEnabled,
          borderRadius: BorderRadius.circular(context.space.buttonRadius.r),
        ),
        child: Text(
          context.l10n.talkImportButtonShort,
          style: context.typo.chipLabel.copyWith(
            color: colors.buttonEnabledText,
          ),
        ),
      ),
    );
  }
}
