import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../core/l10n/date_labels.dart';
import '../../../../core/l10n/l10n_context.dart';
import '../../../../core/theme/theme_context_ext.dart';
import '../../../../core/widgets/app_pressable.dart';
import '../../domain/talk_post.dart';
import 'talk_category_badge.dart';
import 'talk_stat_row.dart';
import 'talk_step_tile.dart';

/// 피드 글 카드 (시안 1783:6713): 분류 · 시간 > 제목 > 한마디 > 카드 그림 4장(+N) > 숫자 줄 | 작성자
/// 카드 전체를 누르면 상세로 간다. 가져오기는 상세에서만 한다
class TalkPostCard extends StatelessWidget {
  const TalkPostCard({super.key, required this.post, required this.onTap});

  final TalkPostSummary post;
  final VoidCallback onTap;

  /// 카드에 그림으로 보이는 최대 장수
  static const _maxVisibleSteps = 4;
  static const _padding = 16.0;

  /// 분류 줄 > 제목 > 한마디 > 그림 > 숫자 줄 간격 (시안 12 · 8 · 16 · 16)
  static const _headToTitle = 12.0;
  static const _titleToNote = 8.0;
  static const _bodyToImages = 16.0;
  static const _imagesToStats = 16.0;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typo = context.typo;
    final l10n = context.l10n;
    final note = post.note;
    final category = post.category;
    final visibleSteps = post.previewSteps.take(_maxVisibleSteps).toList();

    return AppPressable(
      onTap: onTap,
      scaleDown: AppPressable.scaleCard,
      child: Container(
        padding: EdgeInsets.all(_padding.w),
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: BorderRadius.circular(context.space.cardRadius.r),
          border: Border.all(color: colors.talkCardBorder),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 분류 칩 · 오른쪽 시간 (분류 없는 글은 시간만)
            Row(
              children: [
                if (category != null)
                  TalkCategoryBadge(label: category.labelOf(l10n)),
                const Spacer(),
                Text(
                  l10n.timeAgoOf(post.createdAt, DateTime.now()),
                  style: typo.talkMeta.copyWith(color: colors.talkMetaText),
                ),
              ],
            ),
            SizedBox(height: _headToTitle.h),
            Text(
              post.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: typo.talkPostTitle.copyWith(color: colors.talkTitleText),
            ),
            if (note != null && note.isNotEmpty) ...[
              SizedBox(height: _titleToNote.h),
              Text(
                note,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: typo.talkPostNote.copyWith(color: colors.talkMetaText),
              ),
            ],
            if (visibleSteps.isNotEmpty) ...[
              SizedBox(height: _bodyToImages.h),
              _StepImageRow(
                postId: post.id,
                steps: visibleSteps,
                hiddenStepCount: post.stepCount - visibleSteps.length,
                maxVisibleSteps: _maxVisibleSteps,
              ),
            ],
            SizedBox(height: _imagesToStats.h),
            TalkStatRow(
              post: post,
              authorName: post.authorNickname ?? l10n.talkAuthorFallback,
            ),
          ],
        ),
      ),
    );
  }
}

/// 카드 그림 줄: 정사각 4칸 (간격 12), 카드가 더 있으면 마지막 칸 위에 "+N"
/// 4칸 폭을 항상 같게 유지하려고 부족한 칸은 빈 자리로 채운다
class _StepImageRow extends StatelessWidget {
  const _StepImageRow({
    required this.postId,
    required this.steps,
    required this.hiddenStepCount,
    required this.maxVisibleSteps,
  });

  final String postId;
  final List<TalkStep> steps;
  final int hiddenStepCount;
  final int maxVisibleSteps;

  static const _imageGap = 12.0;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (var index = 0; index < maxVisibleSteps; index++) ...[
          if (index > 0) SizedBox(width: _imageGap.w),
          Expanded(
            child: index >= steps.length
                ? const SizedBox.shrink()
                : AspectRatio(
                    aspectRatio: 1,
                    child: TalkStepTile(
                      postId: postId,
                      step: steps[index],
                      overlay: _isLastVisible(index) && hiddenStepCount > 0
                          ? _HiddenCountOverlay(count: hiddenStepCount)
                          : null,
                    ),
                  ),
          ),
        ],
      ],
    );
  }

  bool _isLastVisible(int index) => index == maxVisibleSteps - 1;
}

/// 남은 카드 수 "+N": 어둡게 덮고 흰 글자 (Pretendard 500/14, 시안 1783:6760)
class _HiddenCountOverlay extends StatelessWidget {
  const _HiddenCountOverlay({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return ColoredBox(
      color: colors.sheetScrim,
      child: Center(
        child: Text(
          '+$count',
          style: context.typo.talkPopularTitle.copyWith(
            color: colors.surface,
            height: 1.0,
          ),
        ),
      ),
    );
  }
}
