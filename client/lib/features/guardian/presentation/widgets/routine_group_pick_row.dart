import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../core/l10n/content_locale.dart';
import '../../../../core/l10n/l10n_context.dart';
import '../../../../core/theme/theme_context_ext.dart';
import '../../../../core/widgets/app_pressable.dart';
import '../../../../shared/models/routine.dart';
import 'library_routine_tile.dart';

/// 일과 고르기 한 줄 (시안 1877:9941): 그림 + 제목 + `카드 N장` + 누른 순서 번호
///
/// 고르면 줄 전체가 민트 + 테두리, 오른쪽 원에 순서 번호. 안 골랐으면 흰 줄 + 빈 원.
class RoutineGroupPickRow extends StatelessWidget {
  const RoutineGroupPickRow({
    super.key,
    required this.routine,
    required this.order,
    required this.onTap,
  });

  final Routine routine;

  /// 고른 순서(1부터). 안 골랐으면 null
  final int? order;
  final VoidCallback onTap;

  /// 줄 높이 · 둥글기 · 고른 줄 테두리 두께 (시안 361×68 r20, 2px 안쪽)
  static const _height = 68.0;
  static const _radius = 20.0;
  static const _selectedStrokeWidth = 2.0;

  /// 그림 한 변 · 둥글기 · 줄 왼쪽 여백 · 그림과 글 사이 (시안 52 r12, 8 / 8)
  static const _thumbnailSize = 52.0;
  static const _thumbnailRadius = 12.0;
  static const _thumbnailInset = 8.0;
  static const _thumbnailToText = 8.0;

  /// 제목과 `카드 N장` 사이
  static const _titleToCount = 8.0;

  /// 순서 원 한 변 · 줄 오른쪽 여백 (시안 24, 20)
  static const _orderSize = 24.0;
  static const _orderInsetRight = 20.0;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typo = context.typo;
    final number = order;
    final isPicked = number != null;
    final radius = BorderRadius.circular(_radius.r);
    return Semantics(
      selected: isPicked,
      button: true,
      child: AppPressable(
        onTap: onTap,
        scaleDown: AppPressable.scaleCard,
        child: Container(
          height: _height.h,
          decoration: BoxDecoration(
            // 고른 줄 민트 (목표 칩과 같은 선택색)
            color: isPicked ? colors.goalSelectedFill : colors.surface,
            borderRadius: radius,
          ),
          // 테두리는 위에 덧그린다 — decoration 에 넣으면 두께만큼 안쪽이 밀려 고를 때 줄이 흔들린다
          foregroundDecoration: isPicked
              ? BoxDecoration(
                  borderRadius: radius,
                  border: Border.all(
                    color: colors.goalSelectedBorder,
                    width: _selectedStrokeWidth,
                  ),
                )
              : null,
          child: Row(
            children: [
              SizedBox(width: _thumbnailInset.w),
              _Thumbnail(routine: routine),
              SizedBox(width: _thumbnailToText.w),
              Expanded(
                child: ContentLocale(
                  language: routine.language,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        routine.displayTitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: typo.sheetStepTitle.copyWith(
                          color: colors.sheetTitleText,
                        ),
                      ),
                      // 카드 0장(만들다 만 일과)이면 줄을 숨긴다 — 묶음 열기 줄과 같다
                      if (routine.steps.isNotEmpty) ...[
                        SizedBox(height: _titleToCount.h),
                        Text(
                          context.l10n.routineGroupRowCardCount(
                            routine.steps.length,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: typo.sheetStepBody.copyWith(
                            color: colors.routineTileLabel,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              SizedBox(width: _thumbnailToText.w),
              _OrderCircle(number: number),
              SizedBox(width: _orderInsetRight.w),
            ],
          ),
        ),
      ),
    );
  }
}

/// 일과 그림 52 (둥글기 12 + 1px 테두리)
class _Thumbnail extends StatelessWidget {
  const _Thumbnail({required this.routine});

  final Routine routine;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(RoutineGroupPickRow._thumbnailRadius.r);
    return Container(
      width: RoutineGroupPickRow._thumbnailSize.w,
      height: RoutineGroupPickRow._thumbnailSize.w,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: context.colors.surface,
        borderRadius: radius,
      ),
      // 테두리는 그림 위에 — 그림이 칸을 꽉 채워도 가장자리가 보이게
      foregroundDecoration: BoxDecoration(
        borderRadius: radius,
        border: Border.all(color: context.colors.talkCardBorder),
      ),
      child: LibraryRoutineThumbnail(routine: routine),
    );
  }
}

/// 순서 원: 골랐으면 검정 + 흰 번호, 안 골랐으면 흰 원 + 연한 테두리
class _OrderCircle extends StatelessWidget {
  const _OrderCircle({required this.number});

  final int? number;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final number = this.number;
    final size = RoutineGroupPickRow._orderSize.w;
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: number == null ? colors.surface : colors.textPrimary,
        border: number == null ? Border.all(color: colors.border) : null,
      ),
      child: number == null
          ? null
          : Text(
              '$number',
              style: context.typo.routineSectionLabel.copyWith(
                color: colors.surface,
              ),
            ),
    );
  }
}
