import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../core/l10n/l10n_context.dart';
import '../../../../core/theme/theme_context_ext.dart';
import '../../../../core/widgets/elum_bottom_sheet.dart';
import '../../../../core/widgets/elum_button.dart';
import '../../../../core/widgets/elum_sheet_frame.dart';
import '../../../../core/widgets/elum_text_link.dart';
import '../../../../core/widgets/elum_toast.dart';
import '../../../../core/widgets/settings_group.dart';
import '../../../../core/widgets/settings_switch_tile.dart';
import '../../../../core/widgets/show_failure.dart';
import '../../../../shared/models/routine.dart';
import '../../../reminder/application/routine_reminder_controller.dart';
import '../../../reminder/domain/routine_reminder.dart';

/// 일과 알림 설정 시트 (#777): 시각 고르기 + 매일 반복 > 알림 켜기 / 알림 끄기
class RoutineReminderSheet extends ConsumerStatefulWidget {
  const RoutineReminderSheet({super.key, required this.routine});

  final Routine routine;

  /// 처음 열 때 시각 (알림이 없을 때). 아침 일과가 가장 흔하다
  static const defaultHour = 8;
  static const defaultMinute = 0;

  /// 시각 바퀴 높이
  static const pickerHeight = 180.0;

  static const saveButtonKey = ValueKey('routine.reminder.save');
  static const clearButtonKey = ValueKey('routine.reminder.clear');

  static Future<void> show(BuildContext context, Routine routine) =>
      showElumSheet<void>(
        context: context,
        builder: (_) => RoutineReminderSheet(routine: routine),
      );

  @override
  ConsumerState<RoutineReminderSheet> createState() =>
      _RoutineReminderSheetState();
}

class _RoutineReminderSheetState extends ConsumerState<RoutineReminderSheet> {
  late final RoutineReminder? _existing = ref.read(
    routineReminderProvider,
  )[widget.routine.id];

  late int _hour = _existing?.hour ?? RoutineReminderSheet.defaultHour;
  late int _minute = _existing?.minute ?? RoutineReminderSheet.defaultMinute;
  late bool _isDaily = _existing?.isDaily ?? true;
  var _isSaving = false;

  /// 저장: 권한 > 예약 > 결과 안내 (권한 거부·실패도 시트는 닫히지 않고 이유를 알린다)
  Future<void> _save() async {
    setState(() => _isSaving = true);
    final result = await ref
        .read(routineReminderProvider.notifier)
        .save(
          RoutineReminder(
            routineId: widget.routine.id,
            routineTitle: widget.routine.displayTitle,
            hour: _hour,
            minute: _minute,
            isDaily: _isDaily,
          ),
        );
    if (!mounted) return;
    setState(() => _isSaving = false);
    switch (result) {
      case ReminderSaveResult.scheduled:
        showElumToast(context, context.l10n.reminderSavedToast);
        Navigator.of(context).pop();
      case ReminderSaveResult.permissionDenied:
        showFailure(
          context,
          null,
          title: context.l10n.reminderPermissionDeniedTitle,
          fallback: context.l10n.reminderPermissionDeniedBody,
          fallbackCode: 'E-REMINDER-PERM',
        );
      case ReminderSaveResult.failed:
        showFailure(
          context,
          null,
          title: context.l10n.reminderFailedTitle,
          fallback: context.l10n.reminderFailedBody,
          fallbackCode: 'E-REMINDER',
        );
    }
  }

  Future<void> _clear() async {
    await ref.read(routineReminderProvider.notifier).clear(widget.routine.id);
    if (!mounted) return;
    showElumToast(context, context.l10n.reminderClearedToast);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final space = context.space;
    final l10n = context.l10n;

    // 틀: 제목 > 설명 > 시각 바퀴 > 매일 반복 묶음 > 알림 켜기 > (켜져 있으면) 알림 끄기
    return ElumSheetFrame(
      title: l10n.reminderSheetTitle,
      description: l10n.reminderSheetBody,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            height: RoutineReminderSheet.pickerHeight.h,
            child: CupertinoDatePicker(
              mode: CupertinoDatePickerMode.time,
              initialDateTime: DateTime(2000, 1, 1, _hour, _minute),
              onDateTimeChanged: (value) => setState(() {
                _hour = value.hour;
                _minute = value.minute;
              }),
            ),
          ),
          SizedBox(height: space.md.h),
          SettingsGroup(
            children: [
              SettingsSwitchTile(
                label: l10n.reminderRepeatDaily,
                value: _isDaily,
                onChanged: (on) => setState(() => _isDaily = on),
              ),
            ],
          ),
          SizedBox(height: space.lg.h),
          ElumButton(
            key: RoutineReminderSheet.saveButtonKey,
            label: _existing == null
                ? l10n.reminderTurnOn
                : l10n.reminderUpdate,
            loading: _isSaving,
            onPressed: _isSaving ? null : _save,
          ),
          if (_existing != null) ...[
            SizedBox(height: space.xs.h),
            ElumTextLink(
              key: RoutineReminderSheet.clearButtonKey,
              label: l10n.reminderTurnOff,
              onTap: _isSaving ? null : _clear,
            ),
          ],
        ],
      ),
    );
  }
}
