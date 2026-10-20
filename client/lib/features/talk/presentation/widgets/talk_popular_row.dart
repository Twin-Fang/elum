import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../core/l10n/l10n_context.dart';
import '../../../../core/theme/theme_context_ext.dart';
import '../../../../core/widgets/app_pressable.dart';
import '../../domain/talk_post.dart';
import 'talk_step_image.dart';

/// "많이 가져갔어요 · 이번 주": 제목 줄 + 가로 스크롤 카드 (그림 2x2 · 제목 · N명 가져감)
/// 글이 0건이면 부르는 쪽이 이 위젯을 만들지 않는다
class TalkPopularRow extends StatelessWidget {
  const TalkPopularRow({
    super.key,
    required this.posts,
    required this.onPostTapped,
  });

  final List<TalkPostSummary> posts;
  final ValueChanged<TalkPostSummary> onPostTapped;

  /// 카드 한 장의 폭
  static const _cardWidth = 164.0;
  static const _cardGap = 12.0;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final space = context.space;
    final l10n = context.l10n;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 제목 · 기간
        Padding(
          padding: EdgeInsets.symmetric(horizontal: space.screenH.w),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                l10n.talkPopularTitle,
                style: context.typo.cardTitle.copyWith(
                  color: colors.textPrimary,
                ),
              ),
              SizedBox(width: space.xs.w),
              Text(
                l10n.talkPopularPeriod,
                style: context.typo.caption.copyWith(
                  color: colors.textSecondary,
                ),
              ),
            ],
          ),
        ),
        SizedBox(height: space.sm.h),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: EdgeInsets.symmetric(horizontal: space.screenH.w),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (var index = 0; index < posts.length; index++) ...[
                if (index > 0) SizedBox(width: _cardGap.w),
                SizedBox(
                  width: _cardWidth.w,
                  child: _PopularCard(
                    post: posts[index],
                    onTap: () => onPostTapped(posts[index]),
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _PopularCard extends StatelessWidget {
  const _PopularCard({required this.post, required this.onTap});

  final TalkPostSummary post;
  final VoidCallback onTap;

  /// 2x2 그림에 쓰는 카드 수
  static const _gridStepCount = 4;
  static const _padding = 10.0;
  static const _imageGap = 4.0;
  static const _imageRadius = 8.0;
  static const _titleToCountGap = 4.0;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typo = context.typo;
    final space = context.space;
    final steps = post.previewSteps.take(_gridStepCount).toList();

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
            AspectRatio(
              aspectRatio: 1,
              child: Column(
                children: [
                  for (var row = 0; row < 2; row++) ...[
                    if (row > 0) SizedBox(height: _imageGap.h),
                    Expanded(
                      child: Row(
                        children: [
                          for (var column = 0; column < 2; column++) ...[
                            if (column > 0) SizedBox(width: _imageGap.w),
                            Expanded(child: _gridCell(steps, row * 2 + column)),
                          ],
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
            SizedBox(height: space.xs.h),
            Text(
              post.title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: typo.routineTileTitle.copyWith(
                color: colors.textPrimary,
                height: 1.3,
              ),
            ),
            SizedBox(height: _titleToCountGap.h),
            Text(
              context.l10n.talkPopularImportCount(post.importCount),
              style: typo.caption.copyWith(color: colors.textSecondary),
            ),
          ],
        ),
      ),
    );
  }

  /// 그림 칸 하나 (카드가 모자라면 빈 바탕)
  Widget _gridCell(List<TalkStep> steps, int index) => ClipRRect(
    borderRadius: BorderRadius.circular(_imageRadius.r),
    child: index < steps.length
        ? TalkStepImage(postId: post.id, step: steps[index])
        : const SizedBox.expand(),
  );
}
