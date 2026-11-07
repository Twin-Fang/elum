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
import '../../../member/application/plan_access.dart';
import '../../../subscription/application/plan_paywall_entry.dart';
import '../../application/routine_schedule_controller.dart';
import '../../domain/routine_schedule.dart';
import 'routine_schedule_weekday_picker.dart';
import '../../../subscription/domain/plan_benefit.dart';

/// 반복 요일·시각 시트 (#782, #1080): 요일 고르기 > 시각 바퀴 > 이룸이 기기 알림 스위치 > 저장 / 반복 끄기
///
/// 이룸이 기기 알림이 꺼져 있거나 기기가 없으면 스위치 아래에 한 줄로 알린다. Pro 가 끝나 멈췄으면 그 사실과
/// 남아 있다는 것을 먼저 말하고, 저장은 막되 끄기는 둔다.
class RoutineScheduleSheet extends ConsumerStatefulWidget {
  const RoutineScheduleSheet({super.key, required this.routine});

  final Routine routine;

  /// 처음 열 때 (예약이 없을 때): 평일 오전 8시 — 등교 준비가 가장 흔하다
  static const defaultWeekdays = {1, 2, 3, 4, 5};
  static const defaultHour = 8;
  static const defaultMinute = 0;

  /// 시각 바퀴 높이 (알림 시트와 같은 값)
  static const pickerHeight = 180.0;

  static const saveButtonKey = ValueKey('routine.schedule.save');
  static const turnOffButtonKey = ValueKey('routine.schedule.turnOff');

  static Future<void> show(BuildContext context, Routine routine) =>
      showElumSheet<void>(
        context: context,
        builder: (_) => RoutineScheduleSheet(routine: routine),
      );

  @override
  ConsumerState<RoutineScheduleSheet> createState() =>
      _RoutineScheduleSheetState();
}

class _RoutineScheduleSheetState extends ConsumerState<RoutineScheduleSheet> {
  late final RoutineSchedule? _existing = ref.read(
    routineScheduleOfProvider(widget.routine.id),
  );

  late final Set<int> _weekdays = {
    ...(_existing?.weekdays ?? RoutineScheduleSheet.defaultWeekdays),
  };
  late int _hour = _existing?.hour ?? RoutineScheduleSheet.defaultHour;
  late int _minute = _existing?.minute ?? RoutineScheduleSheet.defaultMinute;
  late bool _isNotifyEnabled = _existing?.isNotifyEnabled ?? true;
  var _isSaving = false;

  void _toggleWeekday(int weekday) => setState(() {
    if (!_weekdays.remove(weekday)) _weekdays.add(weekday);
  });

  /// 저장: 서버 저장 > 토스트·닫기 / 실패 팝업(코드) — 시트는 닫지 않고 고른 값을 둔다
  Future<void> _save() async {
    setState(() => _isSaving = true);
    final failure = await ref
        .read(routineScheduleControllerProvider)
        .save(
          RoutineSchedule(
            routineId: widget.routine.id,
            weekdays: {..._weekdays},
            hour: _hour,
            minute: _minute,
            isNotifyEnabled: _isNotifyEnabled,
          ),
        );
    if (!mounted) return;
    setState(() => _isSaving = false);
    if (failure != null) {
      await _showFailure(failure);
      return;
    }
    showElumToast(context, context.l10n.routineScheduleSavedToast);
    Navigator.of(context).pop();
  }

  /// 끄기: 요금제와 무관하게 언제나 된다
  Future<void> _turnOff() async {
    setState(() => _isSaving = true);
    final failure = await ref
        .read(routineScheduleControllerProvider)
        .turnOff(widget.routine.id);
    if (!mounted) return;
    setState(() => _isSaving = false);
    if (failure != null) {
      await _showFailure(failure);
      return;
    }
    showElumToast(context, context.l10n.routineScheduleTurnedOffToast);
    Navigator.of(context).pop();
  }

  /// 실패 팝업 (서버 Pro 거절이면 실패 대신 Pro 안내)
  Future<void> _showFailure(Object failure) async {
    if (await handleProOnlyRejection(context, ref, failure)) return;
    if (!mounted) return;
    await showFailure(
    context,
    failure,
    title: context.l10n.routineScheduleSaveFailedTitle,
    fallback: context.l10n.routineScheduleSaveFailedFallback,
    fallbackCode: 'E-SCHEDULE',
  );
  }

  @override
  Widget build(BuildContext context) {
    final space = context.space;
    final colors = context.colors;
    final typo = context.typo;
    final l10n = context.l10n;
    final access = ref.watch(planAccessProvider);
    final canSchedule = access.canScheduleRoutines;
    // Free · 판매 중 · Pro 가 반복 일과를 줌: 저장이 꺼진 이유 + Pro 입구 (아니면 권유하지 않음)
    final shouldShowProNote = access.shouldShowTeaserFor(PlanBenefit.routineSchedule);
    final elumiNotification =
        ref.watch(routineSchedulePlanProvider).value?.elumiNotification ??
        ElumiNotificationState.on;
    final hasNoWeekday = _weekdays.isEmpty;
    final isPaused = _existing?.isPaused ?? false;

    final noteStyle = typo.routineTileMeta.copyWith(
      color: colors.routineTileLabel,
    );

    // 틀: 제목 > 설명 > (멈춤 안내) > 요일 > 시각 바퀴 > 알림 스위치(+ 기기 상태) > (Pro 안내) > 저장 > (Pro로 보기) > (있으면) 반복 끄기
    return ElumSheetFrame(
      title: l10n.routineScheduleSheetTitle,
      description: l10n.routineScheduleSheetBody,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (isPaused) ...[
            Text(l10n.routineSchedulePausedNote, style: noteStyle),
            SizedBox(height: space.md.h),
          ],
          RoutineScheduleWeekdayPicker(
            selectedWeekdays: _weekdays,
            onToggle: _isSaving ? null : _toggleWeekday,
          ),
          SizedBox(height: space.md.h),
          SizedBox(
            height: RoutineScheduleSheet.pickerHeight.h,
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
            footer: switch (elumiNotification) {
              ElumiNotificationState.off when _isNotifyEnabled =>
                '${l10n.routineScheduleElumiNotificationOff}\n'
                    '${l10n.routineScheduleElumiNotificationOffHint}',
              ElumiNotificationState.noDevice when _isNotifyEnabled =>
                l10n.routineScheduleElumiNoDevice,
              _ => null,
            },
            children: [
              SettingsSwitchTile(
                label: l10n.routineScheduleNotifyElumi,
                value: _isNotifyEnabled,
                onChanged: (isOn) => setState(() => _isNotifyEnabled = isOn),
              ),
            ],
          ),
          SizedBox(height: space.lg.h),
          if (shouldShowProNote) ...[
            Text(
              l10n.routineScheduleProNote,
              textAlign: TextAlign.center,
              style: noteStyle,
            ),
            SizedBox(height: space.xs.h),
          ] else if (hasNoWeekday) ...[
            Text(
              l10n.routineSchedulePickDayHint,
              textAlign: TextAlign.center,
              style: noteStyle,
            ),
            SizedBox(height: space.xs.h),
          ],
          ElumButton(
            key: RoutineScheduleSheet.saveButtonKey,
            label: l10n.routineScheduleSave,
            loading: _isSaving,
            onPressed: _isSaving || hasNoWeekday || !canSchedule ? null : _save,
          ),
          if (shouldShowProNote) ...[
            SizedBox(height: space.xs.h),
            ElumTextLink(
              label: l10n.proTeaserUnlock,
              onTap: _isSaving ? null : () => openPlanPaywall(context, ref),
            ),
          ],
          if (_existing != null) ...[
            SizedBox(height: space.xs.h),
            ElumTextLink(
              key: RoutineScheduleSheet.turnOffButtonKey,
              label: l10n.routineScheduleTurnOff,
              onTap: _isSaving ? null : _turnOff,
            ),
          ],
        ],
      ),
    );
  }
}
