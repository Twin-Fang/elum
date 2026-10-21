import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../core/l10n/l10n_context.dart';
import '../../../../core/theme/theme_context_ext.dart';
import '../../../../core/widgets/app_pressable.dart';
import '../../domain/talk_post.dart';
import 'talk_stat_row.dart';
import 'talk_step_tile.dart';

/// "이번 주에 많이 가져간 일과에요": 제목 줄 + 가로 스크롤 카드 (시안 1783:6665)
/// 카드: 그림 2x2 > 제목 두 줄 > 숫자 줄. 글이 0건이면 부르는 쪽이 이 위젯을 만들지 않는다
class TalkPopularRow extends StatelessWidget {
  const TalkPopularRow({
    super.key,
    required this.posts,
    required this.onPostTapped,
  });

  final List<TalkPostSummary> posts;
  final ValueChanged<TalkPostSummary> onPostTapped;

  /// 카드 폭 · 카드 사이 · 제목과 카드 사이 (시안 156 · 8 · 16)
  static const _cardWidth = 156.0;
  static const _cardGap = 8.0;
  static const _titleToCards = 16.0;

  @override
  Widget build(BuildContext context) {
    final space = context.space;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.symmetric(horizontal: space.screenH.w),
          child: Text(
            context.l10n.talkPopularTitle,
            style: context.typo.talkSectionTitle.copyWith(
              color: context.colors.talkTitleText,
            ),
          ),
        ),
        SizedBox(height: _titleToCards.h),
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
  static const _gridColumnCount = 2;

  /// 안쪽 여백 · 그림 사이 (시안 8 · 4)
  static const _padding = 8.0;
  static const _imageGap = 4.0;

  /// 그림 > 제목 > 숫자 줄 간격, 아래 여백 (시안 10 · 8 · 10)
  static const _gridToTitle = 10.0;
  static const _titleToStats = 8.0;
  static const _bottomPadding = 10.0;

  /// 제목 두 줄 자리 (14 × 1.2 × 2). 한 줄 제목도 숫자 줄 높이를 카드끼리 맞춘다
  static const _titleMaxLines = 2;
  static const _titleBoxHeight = 34.0;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final steps = post.previewSteps.take(_gridStepCount).toList();

    return AppPressable(
      onTap: onTap,
      scaleDown: AppPressable.scaleCard,
      child: Container(
        padding: EdgeInsets.fromLTRB(
          _padding.w,
          _padding.w,
          _padding.w,
          _bottomPadding.h,
        ),
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: BorderRadius.circular(context.space.cardRadius.r),
          border: Border.all(color: colors.talkCardBorder),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AspectRatio(aspectRatio: 1, child: _grid(steps)),
            SizedBox(height: _gridToTitle.h),
            SizedBox(
              height: _titleBoxHeight.h,
              child: Text(
                post.title,
                maxLines: _titleMaxLines,
                overflow: TextOverflow.ellipsis,
                style: context.typo.talkPopularTitle.copyWith(
                  color: colors.talkTitleText,
                ),
              ),
            ),
            SizedBox(height: _titleToStats.h),
            TalkStatRow(post: post),
          ],
        ),
      ),
    );
  }

  /// 2x2 그림 (카드가 모자라면 테두리만 있는 빈 칸)
  Widget _grid(List<TalkStep> steps) => Column(
    children: [
      for (var row = 0; row < _gridColumnCount; row++) ...[
        if (row > 0) SizedBox(height: _imageGap.w),
        Expanded(
          child: Row(
            children: [
              for (var column = 0; column < _gridColumnCount; column++) ...[
                if (column > 0) SizedBox(width: _imageGap.w),
                Expanded(child: _tile(steps, row * _gridColumnCount + column)),
              ],
            ],
          ),
        ),
      ],
    ],
  );

  Widget _tile(List<TalkStep> steps, int index) => TalkStepTile(
    postId: post.id,
    step: index < steps.length ? steps[index] : null,
  );
}
