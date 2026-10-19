import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../core/l10n/l10n_context.dart';
import '../../../../core/theme/theme_context_ext.dart';
import '../../../../core/widgets/elum_bottom_sheet.dart';
import '../../../../core/widgets/elum_button.dart';
import '../../../../core/widgets/elum_toast.dart';
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
    final colors = context.colors;
    final typo = context.typo;
    final space = context.space;
    final bottomInset = MediaQuery.paddingOf(context).bottom;

    // 여백은 시트 면이 아니라 내용에 준다 (면에 주면 손잡이까지 밀려 제목과 겹친다)
    return ElumSheetSurface(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          space.screenH.w,
          (ElumSheetSurface.defaultHandleTop + space.lg).h,
          space.screenH.w,
          bottomInset + space.md,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              context.l10n.reminderSheetTitle,
              style: typo.sheetTitle.copyWith(color: colors.textPrimary),
            ),
            SizedBox(height: space.xs),
            Text(
              context.l10n.reminderSheetBody,
              style: typo.promptBody.copyWith(color: colors.promptMuted),
            ),
            SizedBox(height: space.md),
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
            SettingsSwitchTile(
              label: context.l10n.reminderRepeatDaily,
              value: _isDaily,
              onChanged: (on) => setState(() => _isDaily = on),
            ),
            SizedBox(height: space.md),
            ElumButton(
              key: RoutineReminderSheet.saveButtonKey,
              label: _existing == null
                  ? context.l10n.reminderTurnOn
                  : context.l10n.reminderUpdate,
              loading: _isSaving,
              onPressed: _isSaving ? null : _save,
            ),
            if (_existing != null) ...[
              SizedBox(height: space.xs),
              TextButton(
                key: RoutineReminderSheet.clearButtonKey,
                onPressed: _isSaving ? null : _clear,
                child: Text(
                  context.l10n.reminderTurnOff,
                  style: typo.promptBody.copyWith(color: colors.promptMuted),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
