import 'package:elum/core/storage/in_memory_storage.dart';
import 'package:elum/core/storage/local_storage.dart';
import 'package:elum/features/guardian/application/routine_manage_coach_notifier.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// 일과관리 코치마크: 언제 뜨고, 무엇을 보여주고, 닫으면 다시 안 뜨는가 (이슈 #832)
void main() {
  ProviderContainer containerWith(InMemoryStorage storage) {
    final container = ProviderContainer(
      overrides: [localStorageProvider.overrideWithValue(storage)],
    );
    addTearDown(container.dispose);
    return container;
  }

  InMemoryStorage unseenStorage() =>
      InMemoryStorage(manageCoachSeen: false, groupCoachSeen: false);

  group('시작 조건', () {
    test('일과가 0개면 뜨지 않는다 — 가리킬 칸이 없다', () {
      final container = containerWith(unseenStorage());
      final isStarted = container
          .read(routineManageCoachProvider.notifier)
          .maybeStart(
            routineCount: 0,
            groupCount: 0,
            hasFirstRoutineTile: false,
          );
      expect(isStarted, isFalse);
      expect(container.read(routineManageCoachProvider).active, isFalse);
    });

    test('일과 1개면 기본 3단계만 뜬다', () {
      final container = containerWith(unseenStorage());
      container
          .read(routineManageCoachProvider.notifier)
          .maybeStart(
            routineCount: 1,
            groupCount: 0,
            hasFirstRoutineTile: true,
          );
      expect(container.read(routineManageCoachProvider).steps, [
        RoutineManageCoachStep.tapRoutine,
        RoutineManageCoachStep.longPressRoutine,
        RoutineManageCoachStep.sentBadge,
      ]);
    });

    test('일과 2개 + 묶음 0개면 묶음 2단계가 이어 붙는다', () {
      final container = containerWith(unseenStorage());
      container
          .read(routineManageCoachProvider.notifier)
          .maybeStart(
            routineCount: 2,
            groupCount: 0,
            hasFirstRoutineTile: true,
          );
      expect(container.read(routineManageCoachProvider).steps, [
        RoutineManageCoachStep.tapRoutine,
        RoutineManageCoachStep.longPressRoutine,
        RoutineManageCoachStep.sentBadge,
        RoutineManageCoachStep.dragToGroup,
        RoutineManageCoachStep.createGroup,
      ]);
    });

    test('이미 묶음이 있으면 묶음 단계는 없다', () {
      final container = containerWith(unseenStorage());
      container
          .read(routineManageCoachProvider.notifier)
          .maybeStart(
            routineCount: 2,
            groupCount: 1,
            hasFirstRoutineTile: true,
          );
      expect(
        container.read(routineManageCoachProvider).steps,
        isNot(contains(RoutineManageCoachStep.dragToGroup)),
      );
    });

    test('첫 칸이 묶음뿐이면(일과 칸 없음) 뜨지 않는다', () {
      final container = containerWith(unseenStorage());
      final isStarted = container
          .read(routineManageCoachProvider.notifier)
          .maybeStart(
            routineCount: 2,
            groupCount: 1,
            hasFirstRoutineTile: false,
          );
      expect(isStarted, isFalse);
    });

    test('기본 3단계를 이미 봤으면 묶음 단계만 뜬다', () {
      final container = containerWith(
        InMemoryStorage(manageCoachSeen: true, groupCoachSeen: false),
      );
      container
          .read(routineManageCoachProvider.notifier)
          .maybeStart(
            routineCount: 2,
            groupCount: 0,
            hasFirstRoutineTile: true,
          );
      expect(container.read(routineManageCoachProvider).steps, [
        RoutineManageCoachStep.dragToGroup,
        RoutineManageCoachStep.createGroup,
      ]);
    });

    test('둘 다 봤으면 뜨지 않는다', () {
      final container = containerWith(InMemoryStorage());
      final isStarted = container
          .read(routineManageCoachProvider.notifier)
          .maybeStart(
            routineCount: 3,
            groupCount: 0,
            hasFirstRoutineTile: true,
          );
      expect(isStarted, isFalse);
    });

    test('저장소를 못 읽으면 봤다고 치고 뜨지 않는다', () {
      final container = containerWith(_UnreadableStorage());
      final isStarted = container
          .read(routineManageCoachProvider.notifier)
          .maybeStart(
            routineCount: 1,
            groupCount: 0,
            hasFirstRoutineTile: true,
          );
      expect(isStarted, isFalse);
    });
  });

  group('진행과 닫기', () {
    test('같은 실행에서 한 번 켠 뒤에는 다시 켜지지 않는다', () async {
      final container = containerWith(unseenStorage());
      final notifier = container.read(routineManageCoachProvider.notifier);
      notifier.maybeStart(
        routineCount: 1,
        groupCount: 0,
        hasFirstRoutineTile: true,
      );
      await notifier.finish();
      final isStartedAgain = notifier.maybeStart(
        routineCount: 1,
        groupCount: 0,
        hasFirstRoutineTile: true,
      );
      expect(isStartedAgain, isFalse);
    });

    test('next 는 순서대로 가고 마지막에서 끝나며 봤음이 저장된다', () async {
      final storage = unseenStorage();
      final container = containerWith(storage);
      final notifier = container.read(routineManageCoachProvider.notifier);
      notifier.maybeStart(
        routineCount: 1,
        groupCount: 0,
        hasFirstRoutineTile: true,
      );
      expect(
        container.read(routineManageCoachProvider).current,
        RoutineManageCoachStep.tapRoutine,
      );
      notifier.next();
      notifier.next();
      expect(
        container.read(routineManageCoachProvider).current,
        RoutineManageCoachStep.sentBadge,
      );
      notifier.next();
      await Future<void>.delayed(Duration.zero);
      expect(container.read(routineManageCoachProvider).active, isFalse);
      expect(storage.isManageCoachSeen, isTrue);
      expect(storage.isGroupCoachSeen, isFalse, reason: '묶음 단계는 안 보여 줬다');
    });

    test('중간에 닫아도(finish) 본 것으로 남고, 묶음 단계가 있었다면 그것도 남는다', () async {
      final storage = unseenStorage();
      final container = containerWith(storage);
      final notifier = container.read(routineManageCoachProvider.notifier);
      notifier.maybeStart(
        routineCount: 2,
        groupCount: 0,
        hasFirstRoutineTile: true,
      );
      await notifier.finish();
      expect(storage.isManageCoachSeen, isTrue);
      expect(storage.isGroupCoachSeen, isTrue);
    });

    test('저장에 실패해도 예외 없이 끝난다', () async {
      final container = containerWith(_UnwritableStorage());
      final notifier = container.read(routineManageCoachProvider.notifier);
      notifier.maybeStart(
        routineCount: 1,
        groupCount: 0,
        hasFirstRoutineTile: true,
      );
      await notifier.finish();
      expect(container.read(routineManageCoachProvider).active, isFalse);
    });

    test('다시 보기(replay)는 봤어도 켜진다', () {
      final container = containerWith(InMemoryStorage());
      container
          .read(routineManageCoachProvider.notifier)
          .replay(routineCount: 1, groupCount: 0);
      expect(container.read(routineManageCoachProvider).active, isTrue);
    });
  });
}

class _UnreadableStorage extends InMemoryStorage {
  @override
  bool get isManageCoachSeen => throw StateError('읽기 실패');
}

class _UnwritableStorage extends InMemoryStorage {
  _UnwritableStorage() : super(manageCoachSeen: false, groupCoachSeen: false);

  @override
  Future<void> setManageCoachSeen(bool v) async => throw StateError('쓰기 실패');
}
