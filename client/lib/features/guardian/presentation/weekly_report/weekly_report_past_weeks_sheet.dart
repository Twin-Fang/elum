import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../core/l10n/date_labels.dart';
import '../../../../core/l10n/l10n_context.dart';
import '../../../../core/theme/theme_context_ext.dart';
import '../../../../core/widgets/elum_bottom_sheet.dart';
import '../../../../core/widgets/elum_error_view.dart';
import '../../../../core/widgets/elum_sheet_frame.dart';
import '../../../../core/widgets/elum_spinner.dart';
import '../../../../core/widgets/settings_group.dart';
import '../../../../core/widgets/settings_tile.dart';
import '../../application/weekly_report_providers.dart';
import '../../domain/weekly_report_weeks.dart';

/// 지난 리포트 목록 시트의 에러 코드 (서버 코드가 없을 때 보임)
const weeklyReportWeeksErrorCode = 'E-WEEKLY-REPORT-WEEKS';

/// 지난 리포트 시트: 주 목록 > 누른 주의 월요일을 돌려줌, 닫으면 null
Future<DateTime?> showWeeklyReportPastWeeksSheet(BuildContext context) {
  return showElumSheet<DateTime>(
    context: context,
    builder: (sheetContext) => ElumSheetFrame(
      title: sheetContext.l10n.weeklyReportPastSheetTitle,
      child: _PastWeeksBody(onWeekSelected: (weekStart) => Navigator.of(sheetContext).pop(weekStart)),
    ),
  );
}

/// 목록 상태 4개: 불러오는 중 / 실패(에러 코드 + 다시 하기) / 비었음 / 주 목록
class _PastWeeksBody extends ConsumerWidget {
  const _PastWeeksBody({required this.onWeekSelected});

  final ValueChanged<DateTime> onWeekSelected;

  static const _stateVerticalPadding = 24.0;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final weeksAsync = ref.watch(weeklyReportWeeksProvider);
    return switch (weeksAsync) {
      AsyncData(value: final weeks) when weeks.weeks.isEmpty => _stateBox(
        Text(
          l10n.weeklyReportPastEmpty,
          textAlign: TextAlign.center,
          style: context.typo.creditHistoryRowTitle.copyWith(color: context.colors.settingsGroupLabel),
        ),
      ),
      AsyncData(value: final weeks) => SettingsGroup(
        children: [for (final week in weeks.weeks) _weekTile(context, week)],
      ),
      AsyncError(:final error) => _stateBox(
        ElumErrorView.failure(
          error,
          fallback: l10n.weeklyReportPastLoadFailed,
          fallbackCode: weeklyReportWeeksErrorCode,
          onRetry: () => ref.invalidate(weeklyReportWeeksProvider),
          compact: true,
        ),
      ),
      _ => _stateBox(const ElumSpinner()),
    };
  }

  Widget _stateBox(Widget child) =>
      Padding(padding: EdgeInsets.symmetric(vertical: _stateVerticalPadding.h), child: Center(child: child));

  Widget _weekTile(BuildContext context, WeeklyReportWeekEntry week) {
    final l10n = context.l10n;
    final weekEnd = DateTime(week.weekStart.year, week.weekStart.month, week.weekStart.day + DateTime.daysPerWeek - 1);
    return SettingsTile(
      label: l10n.weekRangeOf(week.weekStart, weekEnd),
      valueText: l10n.weeklyReportPastWeekValue(week.completedRoutineCount),
      showChevronWithValue: true,
      onTap: () => onWeekSelected(week.weekStart),
    );
  }
}
