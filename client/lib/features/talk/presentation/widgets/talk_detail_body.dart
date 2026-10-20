import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../core/l10n/date_labels.dart';
import '../../../../core/l10n/l10n_context.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/theme/theme_context_ext.dart';
import '../../../../core/widgets/app_pressable.dart';
import '../../domain/talk_post.dart';
import 'talk_category_badge.dart';
import 'talk_step_image.dart';

/// 상세 본문: 닉네임 · 시간 · 분류 > 제목 · 카드 수 > 이렇게 했어요 > 카드 전체 > 도움돼요 · 댓글 수
class TalkDetailBody extends StatelessWidget {
  const TalkDetailBody({
    super.key,
    required this.post,
    required this.onHelpfulPressed,
  });

  final TalkPostDetail post;
  final VoidCallback onHelpfulPressed;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colors = context.colors;
    final typo = context.typo;
    final space = context.space;
    final category = post.category;
    final note = post.note;

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: space.screenH.w),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 닉네임 · 시간 · 분류
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
                TalkCategoryBadge(label: category.labelOf(l10n)),
              ],
            ],
          ),
          SizedBox(height: space.sm.h),
          Text(
            post.title,
            style: typo.sectionTitle.copyWith(
              color: colors.textPrimary,
              height: 1.3,
            ),
          ),
          SizedBox(height: space.xs.h),
          Text(
            l10n.talkDetailStepCount(post.stepCount),
            style: typo.caption.copyWith(color: colors.textSecondary),
          ),
          // 한마디 전문
          if (note != null && note.isNotEmpty) ...[
            SizedBox(height: space.md.h),
            _NoteBox(note: note),
          ],
          SizedBox(height: space.md.h),
          Text(
            l10n.talkStepsTitle,
            style: typo.cardTitle.copyWith(color: colors.textPrimary),
          ),
          SizedBox(height: space.sm.h),
          for (final step in post.steps) ...[
            _StepCard(postId: post.id, step: step),
            SizedBox(height: space.sm.h),
          ],
          // 도움돼요 · 댓글 수
          SizedBox(height: space.xs.h),
          Row(
            children: [
              _HelpfulButton(
                count: post.helpfulCount,
                isSelected: post.isHelpfulByMe,
                onPressed: onHelpfulPressed,
              ),
              SizedBox(width: space.sm.w),
              Text(
                l10n.talkCommentCount(post.commentCount),
                style: typo.tileLabel.copyWith(color: colors.textSecondary),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// 이렇게 했어요: 글쓴이의 한마디 전문
class _NoteBox extends StatelessWidget {
  const _NoteBox({required this.note});

  final String note;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final space = context.space;
    return Container(
      padding: EdgeInsets.all(space.md.w),
      decoration: BoxDecoration(
        color: colors.creditCardBg,
        borderRadius: BorderRadius.circular(space.cardRadius.r),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            context.l10n.talkNoteLabel,
            style: context.typo.tileLabel.copyWith(
              color: colors.textPrimary,
              fontWeight: FontWeight.w800,
            ),
          ),
          SizedBox(height: space.xs.h),
          Text(
            note,
            style: context.typo.body.paragraph.copyWith(
              color: colors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}

/// 카드 한 장: 그림 > 순서 · 제목 > 설명
class _StepCard extends StatelessWidget {
  const _StepCard({required this.postId, required this.step});

  final String postId;
  final TalkStep step;

  /// 그림 가로세로 비율
  static const _imageAspectRatio = 4 / 3;
  static const _numberSize = 24.0;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typo = context.typo;
    final space = context.space;
    final title = step.title;
    final description = step.description;

    return Container(
      padding: EdgeInsets.all(space.sm.w),
      decoration: BoxDecoration(
        color: colors.creditCardBg,
        borderRadius: BorderRadius.circular(space.cardRadius.r),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(space.sm.r),
            child: AspectRatio(
              aspectRatio: _imageAspectRatio,
              child: TalkStepImage(postId: postId, step: step),
            ),
          ),
          SizedBox(height: space.sm.h),
          Row(
            children: [
              Container(
                width: _numberSize.w,
                height: _numberSize.w,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: colors.textPrimary,
                ),
                child: Text(
                  '${step.stepOrder + 1}',
                  style: typo.caption.copyWith(
                    color: colors.surface,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              SizedBox(width: space.xs.w),
              Expanded(
                child: Text(
                  title ?? '',
                  style: typo.tileLabel.copyWith(color: colors.textPrimary),
                ),
              ),
            ],
          ),
          if (description.isNotEmpty) ...[
            SizedBox(height: space.xs.h),
            Text(
              description,
              style: typo.body.paragraph.copyWith(color: colors.textSecondary),
            ),
          ],
        ],
      ),
    );
  }
}

/// 도움돼요 버튼: 누르면 켜지고 다시 누르면 꺼진다
class _HelpfulButton extends StatelessWidget {
  const _HelpfulButton({
    required this.count,
    required this.isSelected,
    required this.onPressed,
  });

  final int count;
  final bool isSelected;
  final VoidCallback onPressed;

  static const _iconSize = 18.0;
  static const _paddingH = 14.0;
  static const _paddingV = 8.0;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final space = context.space;
    return Semantics(
      selected: isSelected,
      button: true,
      child: AppPressable(
        onTap: onPressed,
        child: Container(
          padding: EdgeInsets.symmetric(
            horizontal: _paddingH.w,
            vertical: _paddingV.h,
          ),
          decoration: BoxDecoration(
            color: isSelected ? colors.goalSelectedFill : colors.editChipBg,
            borderRadius: BorderRadius.circular(space.buttonRadius.r),
            border: isSelected
                ? Border.all(
                    color: colors.goalSelectedBorder,
                    width: space.selectedBorderWidth,
                  )
                : null,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                isSelected
                    ? Icons.thumb_up_alt_rounded
                    : Icons.thumb_up_alt_outlined,
                size: _iconSize.w,
                color: colors.textPrimary,
              ),
              SizedBox(width: space.xs.w),
              Text(
                context.l10n.talkHelpfulCount(count),
                style: context.typo.chipLabel.copyWith(
                  color: colors.textPrimary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
