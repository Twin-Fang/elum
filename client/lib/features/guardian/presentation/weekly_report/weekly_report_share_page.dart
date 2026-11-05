import 'package:flutter/material.dart';

import '../../../../core/l10n/date_labels.dart';
import '../../../../core/l10n/l10n_context.dart';
import '../../../../core/theme/theme_context_ext.dart';
import '../../domain/weekly_report.dart';
import '../card_export/print_page.dart';

/// 선생님·치료사에게 보내는 한 장 (A4 595×842 포인트): 제목 > 숫자 4칸 > 월~일 > 일과별 > 남은 카드 > 출처
/// 묶음 사이는 최소 [_blockGap] + 남는 높이를 고르게 나눔 (줄이 적어도 아래 절반이 비지 않게)
///
/// 화면 미리 보기 = 굽는 파일 그대로. Pro 기능이라 워터마크 없음 · 원문·보상 문구 없음.
class WeeklyReportSharePage extends StatelessWidget {
  const WeeklyReportSharePage({super.key, required this.report, required this.elumiName});

  final WeeklyReport report;
  final String elumiName;

  /// 한 장에 넣는 일과 줄 수 (넘치면 마친 횟수 많은 순 앞부분만)
  static const maxRoutineRows = 8;

  // A4 포인트 단위 배치 (기기 크기와 무관)
  static const _pageMargin = 40.0;
  static const _titleToRange = 8.0;
  static const _blockGap = 24.0;
  static const _labelToRows = 8.0;
  static const _rowGap = 6.0;
  static const _statGap = 8.0;

  /// 묶음 사이: 최소 간격 + 남는 높이 몫 (넘치면 최소 간격만)
  static const _blockGapWithShare = [SizedBox(height: _blockGap), Spacer()];

  /// 월~일 칸 위아래 안쪽 · 테두리 모서리 (숫자 칸과 같은 판)
  static const _dayPanelPadding = 16.0;
  static const _panelRadius = 12.0;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final l10n = context.l10n;
    final typo = context.typo;
    final primary = colors.textPrimary;
    final muted = colors.textSecondary;
    final routines = report.routines.take(maxRoutineRows).toList();
    return PrintPage(
      size: PrintPageSize.a4,
      hasWatermark: false,
      showsPictogramCredit: false,
      margin: _pageMargin,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(l10n.weeklyReportShareTitle(elumiName), style: typo.printPageTitle.copyWith(color: primary)),
          const SizedBox(height: _titleToRange),
          Text(
            l10n.weekRangeOf(report.weekStart, report.weekEnd),
            style: typo.printCardDescription.copyWith(color: muted),
          ),
          // 제목·날짜와 숫자 칸은 한 덩어리 (남는 높이는 그 아래 묶음 사이로)
          const SizedBox(height: _blockGap),
          // 숫자 4칸: 완료율 · 받은 별 · 보상까지 간 일과 · 연속으로 마친 날
          Row(
            children: [
              _StatBox(label: l10n.weeklyReportCompletionLabel, valueText: l10n.weeklyReportPercent(report.completionPercent)),
              const SizedBox(width: _statGap),
              _StatBox(label: l10n.weeklyReportStars, valueText: l10n.weeklyReportCount(report.starsEarned)),
              const SizedBox(width: _statGap),
              _StatBox(label: l10n.weeklyReportRewards, valueText: l10n.weeklyReportCount(report.rewardReachedCount)),
              const SizedBox(width: _statGap),
              _StatBox(label: l10n.weeklyReportStreak, valueText: l10n.weeklyReportDays(report.longestCompletedDayStreak)),
            ],
          ),
          const SizedBox(height: _titleToRange),
          Text(
            l10n.weeklyReportCompletionSummary(report.sentRoutineCount, report.completedRoutineCount),
            style: typo.printCardDescription.copyWith(color: primary),
          ),
          ..._blockGapWithShare,
          // 월 ~ 일: 요일 + 마친/보낸 (테두리 판)
          DecoratedBox(
            decoration: BoxDecoration(
              border: Border.all(color: colors.border),
              borderRadius: BorderRadius.circular(_panelRadius),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: _dayPanelPadding),
              child: Row(
            children: [
              for (final day in report.days)
                Expanded(
                  child: Column(
                    children: [
                      Text(l10n.weekdayShortOf(day.date), style: typo.printFooter.copyWith(color: muted)),
                      const SizedBox(height: _rowGap),
                      Text(
                        day.sentCount == 0
                            ? l10n.weeklyReportDayNone
                            : l10n.weeklyReportDayCount(day.completedCount, day.sentCount),
                        style: typo.printCardNumber.copyWith(color: primary),
                      ),
                    ],
                  ),
                ),
            ],
              ),
            ),
          ),
          if (routines.isNotEmpty) ...[
            ..._blockGapWithShare,
            _SectionLabel(text: l10n.weeklyReportRoutinesSection),
            for (final routine in routines)
              _FactRow(
                label: routine.title,
                valueText: l10n.weeklyReportRoutineValue(routine.sentCount, routine.completedCount),
              ),
          ],
          if (report.remainingSteps.isNotEmpty) ...[
            ..._blockGapWithShare,
            _SectionLabel(text: l10n.weeklyReportRemainingSection),
            for (final step in report.remainingSteps)
              _FactRow(
                label: l10n.weeklyReportRemainingLabel(step.routineTitle, step.stepTitle),
                valueText: l10n.weeklyReportTimes(step.remainingCount),
              ),
          ],
          ..._blockGapWithShare,
          Text(l10n.weeklyReportShareNote, style: typo.printFooter.copyWith(color: muted)),
        ],
      ),
    );
  }
}

/// 숫자 한 칸: 값(20) 위 · 이름(12) 아래, 1px 테두리 r12
class _StatBox extends StatelessWidget {
  const _StatBox({required this.label, required this.valueText});

  final String label;
  final String valueText;

  static const _padding = 12.0;
  static const _radius = 12.0;
  static const _valueToLabel = 4.0;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Expanded(
      child: DecoratedBox(
        decoration: BoxDecoration(
          border: Border.all(color: colors.border),
          borderRadius: BorderRadius.circular(_radius),
        ),
        child: Padding(
          padding: const EdgeInsets.all(_padding),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(valueText, style: context.typo.printCardTitle.copyWith(color: colors.textPrimary)),
              const SizedBox(height: _valueToLabel),
              Text(label, style: context.typo.printFooter.copyWith(color: colors.textSecondary)),
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: WeeklyReportSharePage._labelToRows),
      child: Text(text, style: context.typo.printCardTitle.copyWith(color: context.colors.textPrimary)),
    );
  }
}

/// 이름 · 값 한 줄 + 아래 선 (이름이 길면 한 줄에서 자름 — 종이 칸이 넘치지 않게)
class _FactRow extends StatelessWidget {
  const _FactRow({required this.label, required this.valueText});

  final String label;
  final String valueText;

  static const _labelToValue = 12.0;
  static const _rowPaddingV = 10.0;

  @override
  Widget build(BuildContext context) {
    final style = context.typo.printCardDescription.copyWith(color: context.colors.textPrimary);
    return Container(
      padding: const EdgeInsets.symmetric(vertical: _rowPaddingV),
      decoration: BoxDecoration(border: Border(bottom: BorderSide(color: context.colors.border))),
      child: Row(
        children: [
          Expanded(child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: style)),
          const SizedBox(width: _labelToValue),
          Text(valueText, style: style),
        ],
      ),
    );
  }
}
