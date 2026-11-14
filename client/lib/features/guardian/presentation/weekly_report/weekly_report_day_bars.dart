import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../core/l10n/date_labels.dart';
import '../../../../core/l10n/l10n_context.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_motion.dart';
import '../../../../core/theme/theme_context_ext.dart';
import '../../../../core/widgets/app_animated_fraction.dart';
import '../../domain/weekly_report.dart';
import 'weekly_report_chart_card.dart';

/// 요일별 막대 7개: 보낸 일과(연한 색) 위에 끝낸 일과(민트)를 겹침, 위에 `끝낸/보낸`, 오늘 요일은 굵게
///
/// 막대 높이는 그 주 가장 많이 보낸 날 기준 (월요일부터 차례로 바닥에서 자람). 보낸 일과가 0인 날은 낮은 회색 받침만.
class WeeklyReportDayBars extends StatelessWidget {
  const WeeklyReportDayBars({super.key, required this.days, this.today});

  final List<WeeklyReportDay> days;

  /// 굵게 보일 오늘 (null 이면 기기 날짜)
  final DateTime? today;

  static const _barAreaHeight = 96.0;
  static const _barRadius = 8.0;
  static const _barGap = 8.0;
  static const _countToBar = 6.0;
  static const _barToWeekday = 8.0;

  /// 보낸 일과가 있는 날 막대 높이 하한 (비율) / 보낸 일과 0인 날 받침 높이 (비율)
  static const _sentMinFactor = 0.15;
  static const _emptyBaseFactor = 0.08;

  @override
  Widget build(BuildContext context) {
    final todayDate = DateUtils.dateOnly(today ?? DateTime.now());
    final maxSentCount = days.fold<int>(1, (max, day) => math.max(max, day.sentCount));
    return WeeklyReportChartCard(
      title: context.l10n.weeklyReportDaysSection,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          for (final (index, day) in days.indexed)
            Expanded(
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: (_barGap / 2).w),
                child: _DayBar(
                  day: day,
                  index: index,
                  sentFactor: _sentFactorOf(day, maxSentCount),
                  isToday: DateUtils.isSameDay(day.date, todayDate),
                ),
              ),
            ),
        ],
      ),
    );
  }

  double _sentFactorOf(WeeklyReportDay day, int maxSentCount) {
    if (day.sentCount == 0) return _emptyBaseFactor;
    return (day.sentCount / maxSentCount).clamp(_sentMinFactor, 1.0);
  }
}

class _DayBar extends StatelessWidget {
  const _DayBar({required this.day, required this.index, required this.sentFactor, required this.isToday});

  final WeeklyReportDay day;

  /// 요일 순번 (왼쪽부터 차례로 자람)
  final int index;
  final double sentFactor;
  final bool isToday;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colors = context.colors;
    final weekday = l10n.weekdayShortOf(day.date);
    final hasSent = day.sentCount > 0;
    final label = hasSent
        ? l10n.weeklyReportDayBarSemantics(weekday, day.sentCount, day.completedCount)
        : l10n.weeklyReportDayBarEmptySemantics(weekday);
    return Semantics(
      container: true,
      label: label,
      child: ExcludeSemantics(
        child: Column(
          children: [
            // 글자 배율이 커져도 칸 폭 안에 한 줄로
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                hasSent ? '${day.completedCount}/${day.sentCount}' : '-',
                maxLines: 1,
                style: context.typo.ringPercent.copyWith(color: colors.textPrimary),
              ),
            ),
            SizedBox(height: WeeklyReportDayBars._countToBar.h),
            SizedBox(
              height: WeeklyReportDayBars._barAreaHeight.h,
              child: Align(
                alignment: Alignment.bottomCenter,
                // 바닥에서 자람 (요일마다 순차 지연)
                child: AppAnimatedFraction(
                  value: sentFactor,
                  delay: AppMotion.staggerDelayOf(index),
                  builder: (context, fraction) => FractionallySizedBox(
                    heightFactor: fraction,
                    widthFactor: 1,
                    child: _stackedBar(colors, hasSent),
                  ),
                ),
              ),
            ),
            SizedBox(height: WeeklyReportDayBars._barToWeekday.h),
            Text(
              weekday,
              // 같은 글자 모양에 굵기만 달리함 (글자 높이가 달라지면 오늘 칸만 어긋남)
              style: context.typo.creditCaption.copyWith(
                color: isToday ? colors.textPrimary : colors.textSecondary,
                fontWeight: isToday ? FontWeight.w800 : null,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 보낸 일과 막대(연한 색) 안에 끝낸 만큼 민트를 아래부터 채움
  Widget _stackedBar(AppColors colors, bool hasSent) {
    final radius = BorderRadius.circular(WeeklyReportDayBars._barRadius.r);
    return DecoratedBox(
      decoration: BoxDecoration(color: hasSent ? colors.routineRingTrack : colors.routineTileBg, borderRadius: radius),
      child: hasSent && day.completedCount > 0
          ? Align(
              alignment: Alignment.bottomCenter,
              child: FractionallySizedBox(
                heightFactor: day.completionRatio.clamp(0.0, 1.0),
                widthFactor: 1,
                child: DecoratedBox(
                  decoration: BoxDecoration(color: colors.routineRingProgress, borderRadius: radius),
                ),
              ),
            )
          : null,
    );
  }
}
