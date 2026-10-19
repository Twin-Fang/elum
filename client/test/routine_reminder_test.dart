import 'package:elum/core/storage/in_memory_storage.dart';
import 'package:elum/core/storage/local_storage.dart';
import 'package:elum/features/reminder/application/routine_reminder_controller.dart';
import 'package:elum/features/reminder/data/reminder_scheduler.dart';
import 'package:elum/features/reminder/domain/routine_reminder.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeScheduler implements ReminderScheduler {
  _FakeScheduler({this.isPermitted = true});

  final bool isPermitted;
  final scheduled = <int>[];
  final cancelled = <int>[];

  @override
  Future<bool> requestPermission() async => isPermitted;

  @override
  Future<void> schedule(RoutineReminder reminder, ReminderTexts texts) async =>
      scheduled.add(reminder.notificationId);

  @override
  Future<void> cancel(RoutineReminder reminder) async =>
      cancelled.add(reminder.notificationId);
}

const _brushTeeth = RoutineReminder(
  routineId: 'routine-1',
  routineTitle: '양치하기',
  hour: 8,
  minute: 30,
  isDaily: true,
);

ProviderContainer _container(LocalStorage storage, ReminderScheduler scheduler) =>
    ProviderContainer(
      overrides: [
        localStorageProvider.overrideWithValue(storage),
        reminderSchedulerProvider.overrideWithValue(scheduler),
      ],
    );

void main() {
  // 깨지면: 이미 지난 시각을 고르면 알림이 바로 울리거나 영영 안 울린다
  test('다음 울릴 시각: 지났으면 내일, 아직이면 오늘', () {
    final morning = DateTime(2026, 10, 20, 7, 0);
    final evening = DateTime(2026, 10, 20, 21, 0);
    expect(_brushTeeth.nextFireAfter(morning), DateTime(2026, 10, 20, 8, 30));
    expect(_brushTeeth.nextFireAfter(evening), DateTime(2026, 10, 21, 8, 30));
  });

  // 깨지면: 앱을 다시 열면 알림 id 가 달라져 끄기가 옛 알림을 못 지운다
  test('알림 id 는 같은 일과면 항상 같고 양수', () {
    const again = RoutineReminder(
      routineId: 'routine-1',
      routineTitle: '다른 제목',
      hour: 1,
      minute: 0,
      isDaily: false,
    );
    expect(_brushTeeth.notificationId, again.notificationId);
    expect(_brushTeeth.notificationId, greaterThan(0));
  });

  // 깨지면: 앱을 다시 열면 알림 줄이 "알림 없음"으로 돌아간다
  test('켜기 > 저장 > 새로 읽어도 남는다', () async {
    final storage = InMemoryStorage();
    final scheduler = _FakeScheduler();
    final container = _container(storage, scheduler);
    addTearDown(container.dispose);

    final result = await container
        .read(routineReminderProvider.notifier)
        .save(_brushTeeth);

    expect(result, ReminderSaveResult.scheduled);
    expect(scheduler.scheduled, [_brushTeeth.notificationId]);

    final reopened = _container(storage, scheduler);
    addTearDown(reopened.dispose);
    final restored = reopened.read(routineReminderProvider)['routine-1'];
    expect(restored?.hour, 8);
    expect(restored?.minute, 30);
    expect(restored?.isDaily, isTrue);
  });

  // 깨지면: 권한을 거부했는데 화면에는 알림이 켜진 것처럼 보인다
  test('권한 거부 > 예약도 저장도 하지 않는다', () async {
    final scheduler = _FakeScheduler(isPermitted: false);
    final container = _container(InMemoryStorage(), scheduler);
    addTearDown(container.dispose);

    final result = await container
        .read(routineReminderProvider.notifier)
        .save(_brushTeeth);

    expect(result, ReminderSaveResult.permissionDenied);
    expect(scheduler.scheduled, isEmpty);
    expect(container.read(routineReminderProvider), isEmpty);
  });

  // 깨지면: 끈 알림이 계속 울린다
  test('끄기 > 예약 취소 + 목록에서 빠짐', () async {
    final scheduler = _FakeScheduler();
    final container = _container(InMemoryStorage(), scheduler);
    addTearDown(container.dispose);
    final controller = container.read(routineReminderProvider.notifier);

    await controller.save(_brushTeeth);
    await controller.clear('routine-1');

    expect(scheduler.cancelled, [_brushTeeth.notificationId]);
    expect(container.read(routineReminderProvider), isEmpty);
  });

  // 깨지면: 저장값이 깨지면 일과 상세 시트가 열리지 않는다
  test('깨진 저장값은 비우고 시작', () async {
    final storage = InMemoryStorage();
    await storage.setRoutineRemindersJson('{"routine-1": {"hour": "eight"}}');
    final container = _container(storage, _FakeScheduler());
    addTearDown(container.dispose);
    expect(container.read(routineReminderProvider), isEmpty);
  });
}
