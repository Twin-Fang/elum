import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../core/l10n/date_labels.dart';
import '../../../core/l10n/l10n_context.dart';
import '../../../core/router/pop_or_home.dart';
import '../../../core/theme/theme_context_ext.dart';
import '../../../core/widgets/elum_error_view.dart';
import '../../../core/widgets/elum_label_chip.dart';
import '../../../core/widgets/elum_scaffold.dart';
import '../../../core/widgets/elum_state_body.dart';
import '../../../core/widgets/pro_teaser.dart';
import '../../../shared/models/routine.dart';
import '../../member/application/plan_access.dart';
import '../../subscription/application/plan_paywall_entry.dart';
import '../application/routine_providers.dart';
import '../application/routine_schedule_controller.dart';
import '../domain/routine_schedule.dart';
import 'pro_teaser_samples.dart';
import 'widgets/weekly_plan_parts.dart';
import '../../subscription/domain/plan_benefit.dart';

/// 주간 계획 (#782): 월 ~ 일 요일마다 반복 일과를 시각 순으로. 누르면 그 일과의 반복 시트
///
/// 상태: 불러오는 중 / 실패(다시 하기 + 코드) / 예약 0건(글만 든 웜그레이 줄) / 요일 묶음.
/// 위에는 이룸이 기기 알림 상태와 Pro 끝남 멈춤 안내를 한 줄씩 (해당할 때만)
/// Free · 판매 중 · 예약 0건이면 Pro 미리 보기 (견본 주간 계획) (멈춘 예약이 있으면 실제 계획을 보임)
class WeeklyPlanScreen extends ConsumerWidget {
  const WeeklyPlanScreen({super.key});

  /// 제목 줄 y (알림 설정 화면과 같은 하위 화면 결) · 머리 > 첫 묶음 24 · 요일 묶음 사이 24 · 라벨 > 줄 8 · 줄 사이 8
  static const _titleRowTop = ElumScaffold.settingsBackTop;
  static const _topGap = 24.0;
  static const _sectionGap = 24.0;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final planAsync = ref.watch(routineSchedulePlanProvider);
    final routineById = {
      for (final routine in ref.watch(routineLibraryProvider).value ?? const <Routine>[])
        routine.id: routine,
    };

    final access = ref.watch(planAccessProvider);
    final body = switch (planAsync) {
      AsyncValue(:final value?) when value.schedules.isEmpty && access.shouldShowTeaserFor(PlanBenefit.routineSchedule) =>
        ListView(
          padding: EdgeInsets.only(top: WeeklyPlanScreen._topGap.h),
          children: [
            ProTeaser(
              title: context.l10n.proTeaserWeeklyPlanTitle,
              benefit: context.l10n.proTeaserWeeklyPlanBenefit,
              actions: watchProUpsellActions(context, ref, highlight: PlanBenefit.routineSchedule),
              child: ProTeaserSamples.weeklyPlan(context),
            ),
          ],
        ),
      AsyncValue(:final value?) => _PlanBody(plan: value, routineById: routineById),
      AsyncValue(:final error?) => ElumStateBody(
        child: ElumErrorView.failure(
          error,
          fallback: context.l10n.weeklyPlanLoadFailed,
          fallbackCode: 'E-WEEKLY-PLAN',
          onRetry: () => ref.invalidate(routineSchedulePlanProvider),
        ),
      ),
      _ => const ElumStateBody.loading(),
    };

    return ElumScaffold(
      onBack: context.popOrHome,
      title: context.l10n.weeklyPlanTitle,
      backTop: _titleRowTop,
      child: body,
    );
  }
}

class _PlanBody extends StatelessWidget {
  const _PlanBody({required this.plan, required this.routineById});

  final RoutineSchedulePlan plan;
  final Map<String, Routine> routineById;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final space = context.space;
    final today = DateTime.now().weekday;
    final hasNotifyingSchedule = plan.schedules.any(
      (schedule) => schedule.isNotifyEnabled && !schedule.isPaused,
    );
    final deviceNote = switch (plan.elumiNotification) {
      ElumiNotificationState.off when hasNotifyingSchedule =>
        l10n.routineScheduleElumiNotificationOff,
      ElumiNotificationState.noDevice when hasNotifyingSchedule =>
        l10n.routineScheduleElumiNoDevice,
      _ => null,
    };

    return ListView(
      padding: EdgeInsets.only(
        top: WeeklyPlanScreen._topGap.h,
        bottom: space.xl.h,
      ),
      children: [
        // 머리 안내 (해당할 때만): 기기 알림 상태 > 멈춤
        if (deviceNote != null) ...[
          WeeklyPlanNotice(
            text: deviceNote,
            detail: plan.elumiNotification == ElumiNotificationState.off
                ? l10n.routineScheduleElumiNotificationOffHint
                : null,
          ),
          SizedBox(height: space.xs.h),
        ],
        if (plan.hasPausedSchedule) ...[
          WeeklyPlanNotice(text: l10n.routineSchedulePausedNote),
          SizedBox(height: space.xs.h),
        ],
        if (deviceNote != null || plan.hasPausedSchedule)
          SizedBox(height: space.md.h),
        if (plan.schedules.isEmpty)
          const _EmptyPlan()
        else
          for (var weekday = DateTime.monday; weekday <= DateTime.sunday; weekday++) ...[
            _DaySection(
              weekday: weekday,
              isToday: weekday == today,
              schedules: plan.schedulesOn(weekday),
              routineById: routineById,
            ),
            if (weekday != DateTime.sunday)
              SizedBox(height: WeeklyPlanScreen._sectionGap.h),
          ],
      ],
    );
  }
}

/// 요일 묶음: `월요일` (+ 오늘 칩) > 8 > 반복 일과 줄들 (없으면 회색 한 줄)
class _DaySection extends StatelessWidget {
  const _DaySection({
    required this.weekday,
    required this.isToday,
    required this.schedules,
    required this.routineById,
  });

  final int weekday;
  final bool isToday;
  final List<RoutineSchedule> schedules;
  final Map<String, Routine> routineById;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typo = context.typo;
    final space = context.space;
    final l10n = context.l10n;
    final rows = [
      for (final schedule in schedules)
        if (routineById[schedule.routineId] case final routine?)
          WeeklyPlanRoutineRow(routine: routine, schedule: schedule),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Text(
              l10n.weeklyPlanDayTitle(l10n.weekdayShortOfNumber(weekday)),
              style: typo.routineSectionLabel.copyWith(
                color: colors.routineTileLabel,
              ),
            ),
            if (isToday) ...[
              SizedBox(width: space.xs.w),
              ElumLabelChip(
                label: l10n.weeklyPlanToday,
                background: colors.weeklyPlanTodayChipBg,
                foreground: colors.textPrimary,
                border: colors.weeklyPlanTodayChipBorder,
              ),
            ],
          ],
        ),
        SizedBox(height: space.xs.h),
        if (rows.isEmpty)
          Text(
            l10n.weeklyPlanEmptyDay,
            style: typo.routineTileMeta.copyWith(color: colors.routineTileLabel),
          )
        else
          for (final row in rows) ...[
            row,
            if (row != rows.last) SizedBox(height: space.xs.h),
          ],
      ],
    );
  }
}

/// 예약 0건 (보호자 빈 상태 결): 글만 든 웜그레이 줄 — 제목 + 안내 한 줄 (글자가 커지면 칸도 늘어남)
class _EmptyPlan extends StatelessWidget {
  const _EmptyPlan();

  /// 최소 높이 (일과 줄 68) · 안쪽 좌우 18 · 위아래 16
  static const _minHeight = 68.0;
  static const _paddingHorizontal = 18.0;
  static const _paddingVertical = 16.0;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typo = context.typo;
    final space = context.space;
    final l10n = context.l10n;
    return Container(
      constraints: BoxConstraints(minHeight: _minHeight.h),
      padding: EdgeInsets.symmetric(
        horizontal: _paddingHorizontal.w,
        vertical: _paddingVertical.h,
      ),
      decoration: BoxDecoration(
        color: colors.routineTileBg,
        borderRadius: BorderRadius.circular(space.cardRadius),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.weeklyPlanEmptyTitle,
            style: typo.routineTileTitle.copyWith(color: colors.textPrimary),
          ),
          SizedBox(height: space.xs.h),
          Text(
            l10n.weeklyPlanEmptyBody,
            style: typo.routineTileMeta.copyWith(color: colors.routineTileLabel),
          ),
        ],
      ),
    );
  }
}
