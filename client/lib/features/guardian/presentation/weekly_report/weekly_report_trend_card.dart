import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../core/l10n/l10n_context.dart';
import '../../../../core/theme/theme_context_ext.dart';
import '../../domain/weekly_report_trend.dart';
import 'weekly_report_chart_card.dart';

/// 주별 추이 카드 `지난 주들과 견주기`: 주마다 끝낸 일과 수를 꺾은선(점 + 부드러운 선 + 아래 연한 채움)으로
///
/// 점 위 숫자 · 아래 `월/일`, 보고 있는 주의 점만 강조색. [points] 는 오래된 주부터 2개 이상.
class WeeklyReportTrendCard extends StatelessWidget {
  const WeeklyReportTrendCard({super.key, required this.points, required this.highlightedWeekStart});

  final List<WeeklyReportTrendPoint> points;

  /// 강조색으로 그릴 주 월요일 (보고 있는 주)
  final DateTime highlightedWeekStart;

  static const _chartHeight = 112.0;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colors = context.colors;
    final highlightedIndex = points.indexWhere((point) => point.weekStart == highlightedWeekStart);
    return WeeklyReportChartCard(
      title: l10n.weeklyReportTrendSection,
      child: Column(
        children: [
          ExcludeSemantics(
            child: SizedBox(
              height: _chartHeight.h,
              width: double.infinity,
              child: CustomPaint(
                painter: WeeklyReportTrendPainter(
                  counts: [for (final point in points) point.completedRoutineCount],
                  highlightedIndex: highlightedIndex,
                  lineColor: colors.routineRingProgress,
                  highlightColor: colors.weeklyReportInsightTrendAccent,
                  dotCenterColor: colors.settingsGroupBg,
                  gridColor: colors.routineTileBg,
                  dotRadius: context.space.xs.r / 2,
                  strokeWidth: (context.space.xs / 4).w,
                ),
              ),
            ),
          ),
          SizedBox(height: context.space.xs.h),
          Row(
            children: [
              for (final (index, point) in points.indexed)
                Expanded(child: _WeekLabel(point: point, isHighlighted: index == highlightedIndex)),
            ],
          ),
        ],
      ),
    );
  }
}

/// 점 아래 한 칸: 끝낸 일과 수 + `월/일`
class _WeekLabel extends StatelessWidget {
  const _WeekLabel({required this.point, required this.isHighlighted});

  final WeeklyReportTrendPoint point;
  final bool isHighlighted;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colors = context.colors;
    final date = point.weekStart;
    return Semantics(
      container: true,
      label: l10n.weeklyReportTrendPointSemantics(date.month, date.day, point.completedRoutineCount),
      child: ExcludeSemantics(
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Column(
            children: [
              Text(
                '${point.completedRoutineCount}',
                style: context.typo.ringPercent.copyWith(color: colors.textPrimary),
              ),
              Text(
                l10n.weeklyReportTrendWeekLabel(date.month, date.day),
                style: (isHighlighted ? context.typo.ringPercent : context.typo.creditCaption).copyWith(
                  color: isHighlighted ? colors.textPrimary : colors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 꺾은선: 위아래 여유 > 점 좌표(칸 가운데) > 부드러운 선 + 아래 채움 > 점
class WeeklyReportTrendPainter extends CustomPainter {
  const WeeklyReportTrendPainter({
    required this.counts,
    required this.highlightedIndex,
    required this.lineColor,
    required this.highlightColor,
    required this.dotCenterColor,
    required this.gridColor,
    required this.dotRadius,
    required this.strokeWidth,
  });

  final List<int> counts;

  /// 강조할 점 번호 (없으면 -1)
  final int highlightedIndex;
  final Color lineColor;
  final Color highlightColor;
  final Color dotCenterColor;
  final Color gridColor;
  final double dotRadius;
  final double strokeWidth;

  /// 채움 윗면 투명도
  static const _fillAlpha = 0.3;

  @override
  void paint(Canvas canvas, Size size) {
    if (counts.length < 2) return;
    final verticalInset = dotRadius * 2;
    final maxCount = math.max(1, counts.reduce(math.max));
    final columnWidth = size.width / counts.length;
    final points = [
      for (final (index, count) in counts.indexed)
        Offset(
          columnWidth * (index + 0.5),
          verticalInset + (size.height - verticalInset * 2) * (1 - count / maxCount),
        ),
    ];

    // 바닥 기준선
    canvas.drawLine(
      Offset(0, size.height),
      Offset(size.width, size.height),
      Paint()
        ..color = gridColor
        ..strokeWidth = strokeWidth,
    );

    // 부드러운 선 (구간 가운데에서 꺾이지 않고 수평으로 이어져 값을 넘어서 출렁이지 않음)
    final linePath = Path()..moveTo(points.first.dx, points.first.dy);
    for (var index = 1; index < points.length; index++) {
      final previous = points[index - 1];
      final current = points[index];
      final middleX = (previous.dx + current.dx) / 2;
      linePath.cubicTo(middleX, previous.dy, middleX, current.dy, current.dx, current.dy);
    }

    // 아래 연한 채움
    final fillPath = Path.from(linePath)
      ..lineTo(points.last.dx, size.height)
      ..lineTo(points.first.dx, size.height)
      ..close();
    canvas.drawPath(
      fillPath,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [lineColor.withValues(alpha: _fillAlpha), lineColor.withValues(alpha: 0)],
        ).createShader(Offset.zero & size),
    );
    canvas.drawPath(
      linePath,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round
        ..color = lineColor,
    );

    // 점 (속은 판 색, 테두리는 선 색 · 보고 있는 주는 더 크고 강조색으로 채움)
    for (final (index, point) in points.indexed) {
      final isHighlighted = index == highlightedIndex;
      final radius = isHighlighted ? dotRadius * 1.5 : dotRadius;
      canvas.drawCircle(point, radius, Paint()..color = isHighlighted ? highlightColor : dotCenterColor);
      if (!isHighlighted) {
        canvas.drawCircle(
          point,
          radius,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = strokeWidth
            ..color = lineColor,
        );
      }
    }
  }

  @override
  bool shouldRepaint(WeeklyReportTrendPainter oldDelegate) =>
      !listEquals(oldDelegate.counts, counts) ||
      oldDelegate.highlightedIndex != highlightedIndex ||
      oldDelegate.lineColor != lineColor ||
      oldDelegate.highlightColor != highlightColor ||
      oldDelegate.dotCenterColor != dotCenterColor ||
      oldDelegate.gridColor != gridColor ||
      oldDelegate.dotRadius != dotRadius ||
      oldDelegate.strokeWidth != strokeWidth;
}
