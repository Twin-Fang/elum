import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../core/l10n/l10n_context.dart';
import '../../../../core/text/keep_words.dart';
import '../../../../core/theme/theme_context_ext.dart';
import '../../../../core/widgets/app_animated_fraction.dart';
import '../../domain/weekly_report.dart';
import 'weekly_report_chart_card.dart';

/// 주간 리포트 맨 위 요약: 완료율 도넛(가운데 `86%`) + 옆에 `완료율` · `일과 N개 중 M개를 끝냈어요`
///
/// 도넛 = 끝낸 일과 / 보낸 일과 (0 에서 차오름). 숫자만 보여 주고 잘함·못함을 색으로 가르지 않는다.
class WeeklyReportSummaryDonut extends StatelessWidget {
  const WeeklyReportSummaryDonut({super.key, required this.report});

  final WeeklyReport report;

  static const _donutSize = 112.0;
  static const _donutStroke = 14.0;
  static const _donutToText = 20.0;
  static const _labelToSummary = 6.0;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colors = context.colors;
    final percent = report.completionPercent;
    final summary = l10n.weeklyReportDonutSummary(report.sentRoutineCount, report.completedRoutineCount);
    return Semantics(
      container: true,
      label: l10n.weeklyReportDonutSemantics(percent, report.sentRoutineCount, report.completedRoutineCount),
      child: ExcludeSemantics(
        child: WeeklyReportChartCard(
          child: Row(
            children: [
              SizedBox(
                width: _donutSize.w,
                height: _donutSize.w,
                // 0 에서 완료율까지 차오르며 가운데 숫자도 함께 셈
                child: AppAnimatedFraction(
                  value: percent / 100,
                  builder: (context, fraction) => CustomPaint(
                    painter: WeeklyReportDonutPainter(
                      progress: fraction,
                      // 빈 링은 아주 연한 회색: 0% 와 100% 가 한눈에 갈린다 (#1302)
                      trackColor: colors.routineTileBg,
                      fillColor: colors.routineRingProgress,
                      strokeWidth: _donutStroke.w,
                    ),
                    child: Center(
                      // 글자 배율이 커져도 도넛 구멍 안에 한 덩어리로 담는다
                      child: Padding(
                        padding: EdgeInsets.all(_donutStroke.w + context.space.xs.w),
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            '${(fraction * 100).round()}%',
                            maxLines: 1,
                            style: context.typo.subtitle.copyWith(color: colors.textPrimary),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              SizedBox(width: _donutToText.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(l10n.weeklyReportDonutLabel, style: context.typo.creditCaption.copyWith(color: colors.textSecondary)),
                    SizedBox(height: _labelToSummary.h),
                    // 어절 단위로 줄바꿈 (`끝냈어` / `요` 로 꺾이지 않게, #1302)
                    Text(
                      keepWords(summary, locale: context.appLocale),
                      semanticsLabel: summary,
                      style: context.typo.cardTitle.copyWith(color: colors.textPrimary, height: 1.3),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 트랙 원 + 진행 호 (12시 방향에서 시계 방향)
class WeeklyReportDonutPainter extends CustomPainter {
  const WeeklyReportDonutPainter({
    required this.progress,
    required this.trackColor,
    required this.fillColor,
    required this.strokeWidth,
  });

  /// 0.0 ~ 1.0
  final double progress;
  final Color trackColor;
  final Color fillColor;
  final double strokeWidth;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final rect = Rect.fromCircle(center: center, radius: (size.shortestSide - strokeWidth) / 2);
    final trackPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..color = trackColor;
    canvas.drawArc(rect, 0, 2 * math.pi, false, trackPaint);
    final value = progress.clamp(0.0, 1.0);
    if (value <= 0) return;
    final fillPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..color = fillColor;
    canvas.drawArc(rect, -math.pi / 2, 2 * math.pi * value, false, fillPaint);
  }

  @override
  bool shouldRepaint(WeeklyReportDonutPainter oldDelegate) =>
      oldDelegate.progress != progress ||
      oldDelegate.trackColor != trackColor ||
      oldDelegate.fillColor != fillColor ||
      oldDelegate.strokeWidth != strokeWidth;
}
