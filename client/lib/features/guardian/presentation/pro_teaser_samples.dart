import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../core/l10n/l10n_context.dart';
import '../../../core/theme/theme_context_ext.dart';
import '../../../core/l10n/date_labels.dart';
import '../../../shared/models/routine.dart';
import '../domain/routine_memory.dart';
import '../domain/routine_schedule.dart';
import '../domain/weekly_report.dart';
import '../domain/weekly_report_trend.dart';
import 'memory/routine_memory_hero_card.dart';
import 'memory/routine_memory_rows.dart';
import 'weekly_report/weekly_report_sections.dart';
import 'widgets/weekly_plan_parts.dart';

/// Pro 미리 보기(`ProTeaser`) 아래 깔 견본 화면 3개: 주간 리포트 · AI 메모 · 주간 계획
/// 값은 전부 예시 (실제 이룸이 기록·메모를 읽지 않음). 문구는 ARB 견본 키
abstract final class ProTeaserSamples {
  /// 견본 주간 리포트: 이번 주 월요일부터 7일, 보낸 일과 3개 · 마친 비율 예시 값
  static WeeklyReport weeklyReport(AppLocalizations l10n, DateTime today) {
    final monday = DateTime(today.year, today.month, today.day - (today.weekday - DateTime.monday));
    // 요일별 (보낸, 마친) 예시 값
    const dayCounts = [(3, 3), (3, 2), (3, 3), (2, 1), (3, 3), (1, 1), (0, 0)];
    return WeeklyReport(
      weekStart: monday,
      weekEnd: monday.add(const Duration(days: 6)),
      isCurrentWeek: true,
      sentRoutineCount: 15,
      completedRoutineCount: 13,
      completionPercent: 86,
      starsEarned: 42,
      rewardReachedCount: 5,
      longestCompletedDayStreak: 3,
      days: [
        for (final (index, (sent, completed)) in dayCounts.indexed)
          WeeklyReportDay(date: monday.add(Duration(days: index)), sentCount: sent, completedCount: completed),
      ],
      routines: [
        WeeklyReportRoutine(title: l10n.proTeaserSampleRoutineMorning, sentCount: 6, completedCount: 6),
        WeeklyReportRoutine(title: l10n.proTeaserSampleRoutineBrush, sentCount: 6, completedCount: 5),
        WeeklyReportRoutine(title: l10n.proTeaserSampleRoutineBag, sentCount: 3, completedCount: 2),
      ],
      remainingSteps: [
        WeeklyReportRemainingStep(
          routineTitle: l10n.proTeaserSampleRoutineMorning,
          stepTitle: l10n.proTeaserSampleStepSocks,
          remainingCount: 1,
        ),
      ],
    );
  }

  /// 견본 주간 계획: 월 · 수 · 금 아침에 같은 견본 일과 줄 (누름은 `ProTeaser` 가 막음)
  static Widget weeklyPlan(BuildContext context) {
    final l10n = context.l10n;
    final space = context.space;
    final sampleRoutines = [
      Routine(id: 'sample-morning', title: l10n.proTeaserSampleRoutineMorning),
      Routine(id: 'sample-brush', title: l10n.proTeaserSampleRoutineBrush),
    ];
    const sampleWeekdays = [DateTime.monday, DateTime.wednesday, DateTime.friday];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final weekday in sampleWeekdays) ...[
          Text(
            l10n.weeklyPlanDayTitle(l10n.weekdayShortOfNumber(weekday)),
            style: context.typo.routineSectionLabel.copyWith(color: context.colors.routineTileLabel),
          ),
          SizedBox(height: space.xs.h),
          for (final (index, routine) in sampleRoutines.indexed) ...[
            WeeklyPlanRoutineRow(
              routine: routine,
              schedule: RoutineSchedule(
                routineId: routine.id,
                weekdays: sampleWeekdays.toSet(),
                hour: 8 + index,
                minute: 0,
              ),
            ),
            SizedBox(height: space.xs.h),
          ],
          SizedBox(height: space.md.h),
        ],
      ],
    );
  }

  /// 견본 AI 메모리: 위 카드(PRO 배지 + 숫자 3칸) + 규칙 3줄 (실제 화면과 같은 모양)
  static Widget routineMemory(BuildContext context) {
    final l10n = context.l10n;
    MemoryRule sampleRule(String id, String summary, MemoryRuleType type, MemoryRuleStatus status, int count) => MemoryRule(
      id: id,
      type: type,
      status: status,
      source: type == MemoryRuleType.manual ? MemoryRuleSource.manual : MemoryRuleSource.ai,
      summary: summary,
      evidenceCount: count,
    );
    final rules = [
      sampleRule('sample-1', l10n.proTeaserSampleMemoryShort, MemoryRuleType.word, MemoryRuleStatus.active, 3),
      sampleRule('sample-2', l10n.proTeaserSampleMemoryOrder, MemoryRuleType.split, MemoryRuleStatus.active, 4),
      sampleRule('sample-3', l10n.proTeaserSampleMemoryReward, MemoryRuleType.manual, MemoryRuleStatus.active, 0),
    ];
    final memory = RoutineMemory(isEnabled: true, autoApplyCount: RoutineMemory.defaultAutoApplyCount, rules: rules, edits: const []);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        RoutineMemoryHeroCard(
          elumiName: l10n.commonElumiName,
          memory: memory,
          selectedTab: RoutineMemoryTab.applied,
          onTabSelected: (_) {},
          isProBadgeShown: true,
        ),
        SizedBox(height: context.space.sm.h),
        for (final rule in rules)
          MemoryRuleRow(rule: rule, autoApplyCount: memory.autoApplyCount, onTap: () {}, onSwitchChanged: (_) {}),
      ],
    );
  }

  /// 견본 주간 리포트 화면 (요약·기록 묶음 그대로)
  static Widget weeklyReportSections(BuildContext context) =>
      WeeklyReportSections(
        report: weeklyReport(context.l10n, DateTime.now()),
        sampleTrendPoints: weeklyReportTrendPoints(DateTime.now()),
      );

  /// 견본 주별 추이: 이번 주까지 5주 (끝낸 일과 수 예시 값)
  static List<WeeklyReportTrendPoint> weeklyReportTrendPoints(DateTime today) {
    final monday = DateTime(today.year, today.month, today.day - (today.weekday - DateTime.monday));
    const completedCounts = [9, 11, 8, 12, 13];
    return [
      for (final (index, count) in completedCounts.indexed)
        WeeklyReportTrendPoint(
          weekStart: DateTime(
            monday.year,
            monday.month,
            monday.day - DateTime.daysPerWeek * (completedCounts.length - 1 - index),
          ),
          completedRoutineCount: count,
        ),
    ];
  }
}
