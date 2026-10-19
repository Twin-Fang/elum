import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/current_l10n.dart';
import '../../../core/logger/app_logger.dart';
import '../../../core/storage/local_storage.dart';
import '../data/reminder_scheduler.dart';
import '../domain/routine_reminder.dart';

/// 알림 켜기 결과: 성공 하나, 실패는 사유별
enum ReminderSaveResult { scheduled, permissionDenied, failed }

final reminderSchedulerProvider = Provider<ReminderScheduler>(
  (ref) => LocalNotificationReminderScheduler(),
);

/// 일과별 알림 상태 (#777): 저장소 읽기 > 켜기(권한 > 예약 > 저장) / 끄기(취소 > 저장)
///
/// 상태는 `일과 id > 알림`. 예약은 이 기기에만 걸린다.
class RoutineReminderController extends Notifier<Map<String, RoutineReminder>> {
  @override
  Map<String, RoutineReminder> build() {
    try {
      final raw = ref.read(localStorageProvider).routineRemindersJson;
      if (raw == null || raw.isEmpty) return const {};
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return const {};
      final reminders = <String, RoutineReminder>{};
      for (final entry in decoded.entries) {
        final reminder = RoutineReminder.tryFromJson(
          entry.key.toString(),
          entry.value,
        );
        if (reminder != null) reminders[reminder.routineId] = reminder;
      }
      return reminders;
    } catch (e, st) {
      // 깨진 저장값은 비우고 시작 (알림 화면이 열리지 않는 것보다 낫다)
      AppLogger.error('RoutineReminderController.build', e, st);
      return const {};
    }
  }

  /// 알림 켜기·시각 바꾸기
  Future<ReminderSaveResult> save(RoutineReminder reminder) async {
    final scheduler = ref.read(reminderSchedulerProvider);
    try {
      if (!await scheduler.requestPermission()) {
        return ReminderSaveResult.permissionDenied;
      }
      await scheduler.schedule(reminder, _textsFor(reminder));
    } catch (e, st) {
      AppLogger.error('RoutineReminderController.save', e, st);
      return ReminderSaveResult.failed;
    }
    state = {...state, reminder.routineId: reminder};
    await _persist();
    return ReminderSaveResult.scheduled;
  }

  /// 알림 끄기. 예약이 없어도 조용히 끝난다
  Future<void> clear(String routineId) async {
    final reminder = state[routineId];
    if (reminder == null) return;
    try {
      await ref.read(reminderSchedulerProvider).cancel(reminder);
    } catch (e, st) {
      // 취소가 실패해도 목록에서는 뺀다 (다음 예약 때 같은 id 로 덮인다)
      AppLogger.error('RoutineReminderController.clear', e, st);
    }
    state = {...state}..remove(routineId);
    await _persist();
  }

  ReminderTexts _textsFor(RoutineReminder reminder) => (
    channelName: appL10n.reminderChannelName,
    title: appL10n.reminderNotificationTitle,
    body: appL10n.reminderNotificationBody(reminder.routineTitle),
  );

  Future<void> _persist() async {
    try {
      await ref
          .read(localStorageProvider)
          .setRoutineRemindersJson(
            jsonEncode({
              for (final reminder in state.values)
                reminder.routineId: reminder.toJson(),
            }),
          );
    } catch (e, st) {
      // 저장이 안 돼도 예약은 걸려 있다 — 앱을 다시 열면 화면 표시만 사라진다
      AppLogger.error('RoutineReminderController._persist', e, st);
    }
  }
}

final routineReminderProvider =
    NotifierProvider<RoutineReminderController, Map<String, RoutineReminder>>(
      RoutineReminderController.new,
    );
