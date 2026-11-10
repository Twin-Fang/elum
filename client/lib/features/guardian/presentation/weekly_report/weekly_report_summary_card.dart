import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../core/l10n/l10n_context.dart';
import '../../../../core/theme/theme_context_ext.dart';
import '../../domain/weekly_report.dart';

/// 루미 정리 글 카드: 작은 제목 > 줄을 이은 한 문단 (연보라 판 r20)
///
/// 사실만 적힌 글이라 평가·조언 없음. 부르는 쪽이 정리 글이 있을 때만 놓는다.
class WeeklyReportSummaryCard extends StatelessWidget {
  const WeeklyReportSummaryCard({super.key, required this.summary});

  final WeeklyReportSummary summary;

  static const _padding = 20.0;
  static const _eyebrowToBody = 8.0;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.weeklyReportSummaryFill,
        borderRadius: BorderRadius.circular(context.space.cardRadius.r),
      ),
      child: Padding(
        padding: EdgeInsets.all(_padding.w),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              context.l10n.weeklyReportSummaryEyebrow,
              style: context.typo.creditCaption.copyWith(color: colors.textSecondary),
            ),
            SizedBox(height: _eyebrowToBody.h),
            Text(summary.paragraph, style: context.typo.creditBody.copyWith(color: colors.textPrimary)),
          ],
        ),
      ),
    );
  }
}

/// 숫자 3개: 끝낸 일과 · 받은 별 · 남은 카드 (흰 판 r20, 값 위 · 이름 아래)
class WeeklyReportStatRow extends StatelessWidget {
  const WeeklyReportStatRow({super.key, required this.report});

  final WeeklyReport report;

  static const _gap = 8.0;
  static const _padding = 12.0;
  static const _valueToLabel = 4.0;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final remainingCardCount = report.remainingSteps.fold<int>(0, (sum, step) => sum + step.remainingCount);
    final stats = [
      (value: report.completedRoutineCount, label: l10n.weeklyReportStatCompleted),
      (value: report.starsEarned, label: l10n.weeklyReportStars),
      (value: remainingCardCount, label: l10n.weeklyReportStatRemaining),
    ];
    return Row(
      children: [
        for (final (index, stat) in stats.indexed) ...[
          if (index > 0) SizedBox(width: _gap.w),
          Expanded(child: _StatBox(value: stat.value, label: stat.label)),
        ],
      ],
    );
  }
}

class _StatBox extends StatelessWidget {
  const _StatBox({required this.value, required this.label});

  final int value;
  final String label;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.settingsGroupBg,
        borderRadius: BorderRadius.circular(context.space.cardRadius.r),
      ),
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: WeeklyReportStatRow._padding.h, horizontal: context.space.xs.w),
        child: Column(
          children: [
            Text('$value', style: context.typo.subtitle.copyWith(color: colors.textPrimary)),
            SizedBox(height: WeeklyReportStatRow._valueToLabel.h),
            Text(
              label,
              textAlign: TextAlign.center,
              style: context.typo.creditCaption.copyWith(color: colors.textSecondary),
            ),
          ],
        ),
      ),
    );
  }
}
