import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../../core/assets/app_assets.dart';
import '../../../../core/l10n/content_locale.dart';
import '../../../../core/l10n/l10n_context.dart';
import '../../../../core/theme/theme_context_ext.dart';
import '../../../../core/widgets/app_pressable.dart';
import '../../../../shared/models/routine.dart';
import '../../domain/routine_schedule.dart';
import 'library_routine_tile.dart';
import 'routine_schedule_labels.dart';
import 'routine_schedule_sheet.dart';

// 주간 계획 화면 조각: 머리 안내 한 줄, 반복 일과 한 줄

/// 머리 안내 (흰 판 r20): 빗금 종 + 한 줄 (+ 회색 둘째 줄). 기기 알림 꺼짐 · 기기 없음 · Pro 끝남 멈춤
class WeeklyPlanNotice extends StatelessWidget {
  const WeeklyPlanNotice({super.key, required this.text, this.detail});

  final String text;
  final String? detail;

  /// 판 최소 높이 56 · 안쪽 좌우 20 위아래 16 · 아이콘 20 · 아이콘 > 글 12 (알림 꺼짐 띠와 같은 결)
  static const _minHeight = 56.0;
  static const _paddingHorizontal = 20.0;
  static const _paddingVertical = 16.0;
  static const _iconSize = 20.0;
  static const _iconToText = 12.0;
  static const _lineGap = 4.0;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typo = context.typo;
    final space = context.space;
    final detail = this.detail;
    return Container(
      constraints: BoxConstraints(minHeight: _minHeight.h),
      padding: EdgeInsets.symmetric(
        horizontal: _paddingHorizontal.w,
        vertical: _paddingVertical.h,
      ),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(space.cardRadius),
      ),
      child: Row(
        children: [
          SvgPicture.asset(
            AppAssets.iconBellSlash,
            width: _iconSize.w,
            height: _iconSize.w,
            excludeFromSemantics: true,
            colorFilter: ColorFilter.mode(colors.routineTileLabel, BlendMode.srcIn),
          ),
          SizedBox(width: _iconToText.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(text, style: typo.settingsTileLabel.copyWith(color: colors.textPrimary)),
                if (detail != null) ...[
                  SizedBox(height: _lineGap.h),
                  Text(
                    detail,
                    style: typo.routineTileMeta.copyWith(color: colors.routineTileLabel),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// 반복 일과 한 줄 (홈 일과 줄 결 361×68 r20 웜그레이): 첫 카드 그림 52 + 제목 + `오전 8:00` · 상태
/// 누르면 그 일과의 반복 시트
class WeeklyPlanRoutineRow extends StatelessWidget {
  const WeeklyPlanRoutineRow({
    super.key,
    required this.routine,
    required this.schedule,
  });

  final Routine routine;
  final RoutineSchedule schedule;

  /// 홈 일과 줄 실측: 높이 68 · 그림 52 r12 · 그림 둘레 8(그림 > 글 8 포함) · 오른쪽 16 · 제목 > 메타 8
  static const _minHeight = 68.0;
  static const _thumbnailSize = 52.0;
  static const _thumbnailRadius = 12.0;
  static const _thumbnailInset = 8.0;
  static const _paddingRight = 16.0;
  static const _titleToMeta = 8.0;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typo = context.typo;
    final space = context.space;
    final l10n = context.l10n;
    final status = schedule.isPaused
        ? l10n.routineSchedulePaused
        : schedule.isNotifyEnabled
        ? null
        : l10n.weeklyPlanNotifyOff;
    final meta = [
      routineScheduleTimeLabel(context, schedule),
      ?status,
    ].join(l10n.weeklyPlanMetaSeparator);

    return AppPressable(
      onTap: () => RoutineScheduleSheet.show(context, routine),
      scaleDown: AppPressable.scaleCard,
      child: Container(
        constraints: BoxConstraints(minHeight: _minHeight.h),
        padding: EdgeInsets.only(right: _paddingRight.w),
        decoration: BoxDecoration(
          color: colors.routineTileBg,
          borderRadius: BorderRadius.circular(space.cardRadius),
        ),
        child: Row(
          children: [
            Padding(
              padding: EdgeInsets.all(_thumbnailInset.w),
              child: RoutineThumbnailBox(
                routine: routine,
                size: _thumbnailSize,
                radius: _thumbnailRadius,
              ),
            ),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ContentLocale(
                    language: routine.language,
                    child: Text(
                      routine.displayTitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: typo.routineTileTitle.copyWith(color: colors.textPrimary),
                    ),
                  ),
                  SizedBox(height: _titleToMeta.h),
                  Text(
                    meta,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: typo.routineTileMeta.copyWith(
                      color: schedule.isPaused ? colors.rewardEmptyLabel : colors.routineTileLabel,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
