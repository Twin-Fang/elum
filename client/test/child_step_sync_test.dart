import 'dart:async';

import 'package:dio/dio.dart';
import 'package:elum/features/child/application/child_routine_notifier.dart';
import 'package:elum/features/child/data/step_progress_repository.dart';
import 'package:elum/features/guardian/data/routine_repository.dart';
import 'package:elum/shared/models/action_card.dart';
import 'package:elum/shared/models/routine.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/test_storage.dart';

/// 카드 완료 체크와 서버 동기화의 정합성.
///
/// 서버(`RoutineService.completeStep`/`cancelStep`)는 **이전 단계가 미완료면
/// 완료를 거부(409)** 하고 **마지막에 완료한 단계만 취소를 허용**한다.
/// 화면이 이 규칙을 모르고 아무 순서로나 체크를 허용하고 거부 응답을 삼키면,
/// 화면은 100%인데 서버는 57%인 상태가 생긴다 (실제 운영 로그로 확인).
///
/// 그래서 세 겹으로 막는다.
/// 1. 화면이 서버와 같은 순서 규칙을 지킨다 — 거부될 요청을 애초에 보내지 않는다
/// 2. 그래도 서버가 거부하면 로컬 체크를 되돌린다 — 화면이 거짓말하지 않는다
/// 3. 동기화 요청은 탭 순서대로 직렬 전송한다 — 앞 요청이 끝나기 전에 뒤가 나가지 않는다
void main() {
  const c1 = ActionCard(id: 'c1', description: '옷을 입어요', stepOrder: 1);
  const c2 = ActionCard(id: 'c2', description: '우산을 챙겨요', stepOrder: 2);
  const c3 = ActionCard(id: 'c3', description: '신발을 신어요', stepOrder: 3);
  const routine = Routine(
    id: 'r1',
    title: '비 오는 날 학교에 가요',
    status: 'CONFIRMED',
    steps: [c1, c2, c3],
  );

  ({ProviderContainer container, _FakeStepRepo repo}) setUp({
    bool accept = true,
  }) {
    final repo = _FakeStepRepo(accept: accept);
    final container = ProviderContainer(
      overrides: [
        testStorageOverride(onboardingCompleted: true),
        stepProgressRepositoryProvider.overrideWithValue(repo),
        // 동기화 후 목록 갱신이 실서버를 타지 않게 한다
        todayRoutinesProvider.overrideWith((ref) async => const <Routine>[]),
        myRoutinesProvider.overrideWith((ref) async => const <Routine>[]),
      ],
    );
    addTearDown(container.dispose);
    return (container: container, repo: repo);
  }

  group('순서 규칙 — 서버와 같은 규칙을 화면이 먼저 지킨다', () {
    test('이전 단계가 미완료면 체크되지 않고 서버로도 보내지 않는다', () async {
      final (:container, :repo) = setUp();
      final notifier = container.read(childRoutineProvider.notifier);

      final rewarded = notifier.toggle(routine: routine, card: c2);
      await repo.drain();

      expect(rewarded, isFalse);
      expect(container.read(childRoutineProvider).isChecked(c2), isFalse);
      expect(repo.calls, isEmpty, reason: '거부될 요청은 애초에 보내지 않는다');
    });

    test('순서대로 체크하면 전부 체크되고 서버에도 순서대로 간다', () async {
      final (:container, :repo) = setUp();
      final notifier = container.read(childRoutineProvider.notifier);

      notifier.toggle(routine: routine, card: c1);
      notifier.toggle(routine: routine, card: c2);
      notifier.toggle(routine: routine, card: c3);
      await repo.drain();

      final state = container.read(childRoutineProvider);
      expect(state.isChecked(c1), isTrue);
      expect(state.isChecked(c2), isTrue);
      expect(state.isChecked(c3), isTrue);
      expect(repo.calls, ['complete c1', 'complete c2', 'complete c3']);
    });

    test('마지막에 체크한 카드만 해제할 수 있다', () async {
      final (:container, :repo) = setUp();
      final notifier = container.read(childRoutineProvider.notifier);
      notifier.toggle(routine: routine, card: c1);
      notifier.toggle(routine: routine, card: c2);
      await repo.drain();

      // 뒤(c2)가 체크된 상태에서 앞(c1)은 풀 수 없다 — 서버도 409를 준다
      notifier.toggle(routine: routine, card: c1);
      await repo.drain();
      expect(container.read(childRoutineProvider).isChecked(c1), isTrue);
      expect(repo.calls, hasLength(2), reason: 'cancel c1은 보내지 않는다');

      // 마지막(c2)은 풀린다
      notifier.toggle(routine: routine, card: c2);
      await repo.drain();
      expect(container.read(childRoutineProvider).isChecked(c2), isFalse);
      expect(repo.calls.last, 'cancel c2');
    });

    test('canToggle이 체크 버튼 활성 조건을 알려준다', () async {
      final (:container, :repo) = setUp();
      final notifier = container.read(childRoutineProvider.notifier);

      expect(notifier.canToggle(routine: routine, card: c1), isTrue);
      expect(notifier.canToggle(routine: routine, card: c2), isFalse);

      notifier.toggle(routine: routine, card: c1);
      expect(notifier.canToggle(routine: routine, card: c2), isTrue);
      // c1은 이제 "마지막 체크"라 해제 가능
      expect(notifier.canToggle(routine: routine, card: c1), isTrue);

      notifier.toggle(routine: routine, card: c2);
      // c2가 뒤에 체크돼 c1은 해제 불가
      expect(notifier.canToggle(routine: routine, card: c1), isFalse);

      // 동기화 체인이 컨테이너 dispose 뒤까지 살아남지 않게 비운다
      await repo.drain();
    });
  });

  group('서버 거부 시 되돌림 — 화면이 거짓말하지 않는다', () {
    test('서버가 완료를 거부하면 로컬 체크가 풀린다', () async {
      final (:container, :repo) = setUp(accept: false);
      final notifier = container.read(childRoutineProvider.notifier);

      notifier.toggle(routine: routine, card: c1);
      // 낙관적으로 먼저 체크된다 — 아동이 누르는 즉시 반응해야 한다
      expect(container.read(childRoutineProvider).isChecked(c1), isTrue);

      await repo.drain();

      expect(
        container.read(childRoutineProvider).isChecked(c1),
        isFalse,
        reason: '서버에 남지 않은 체크를 화면에 남기면 재진입 시 되돌아간다',
      );
    });

    // 취소 거부 시 되돌림은 아래 "서버가 이미 완료한 카드" 그룹에서 본다 —
    // 거부 후 화면은 서버 값(`completed`)으로 돌아가므로 서버 완료 카드로 검증해야 맞다.
  });

  group('서버가 이미 완료한 카드 — 재진입 후에도 맞게 동작한다', () {
    // 앱을 다시 열면 로컬 상태는 없고 서버 `completed`만 있다.
    const serverDone = ActionCard(
      id: 'c1',
      description: '옷을 입어요',
      stepOrder: 1,
      completed: true,
    );
    const resumed = Routine(
      id: 'r1',
      status: 'CONFIRMED',
      steps: [serverDone, c2, c3],
    );

    test('서버 완료 카드는 체크로 보이고, 다음 카드를 이어서 체크할 수 있다', () async {
      final (:container, :repo) = setUp();
      final notifier = container.read(childRoutineProvider.notifier);

      expect(
        container.read(childRoutineProvider).isChecked(serverDone),
        isTrue,
      );

      notifier.toggle(routine: resumed, card: c2);
      await repo.drain();

      expect(container.read(childRoutineProvider).isChecked(c2), isTrue);
      expect(repo.calls, ['complete c2']);
    });

    test('서버 완료 카드를 해제하면 cancel을 보내고 화면도 풀린다', () async {
      final (:container, :repo) = setUp();
      final notifier = container.read(childRoutineProvider.notifier);

      notifier.toggle(routine: resumed, card: serverDone);
      await repo.drain();

      expect(
        container.read(childRoutineProvider).isChecked(serverDone),
        isFalse,
      );
      expect(repo.calls, ['cancel c1']);
    });

    test('서버 완료 카드 해제가 거부되면 다시 체크로 돌아온다', () async {
      final (:container, :repo) = setUp(accept: false);
      final notifier = container.read(childRoutineProvider.notifier);

      notifier.toggle(routine: resumed, card: serverDone);
      await repo.drain();

      expect(
        container.read(childRoutineProvider).isChecked(serverDone),
        isTrue,
      );
    });
  });

  group('동기화 직렬화 — 탭 순서가 서버 도착 순서다', () {
    test('앞 요청이 끝나기 전에는 뒤 요청을 보내지 않는다', () async {
      final (:container, :repo) = setUp();
      repo.hold = true; // 서버 응답을 잡아둔다
      final notifier = container.read(childRoutineProvider.notifier);

      notifier.toggle(routine: routine, card: c1);
      notifier.toggle(routine: routine, card: c2);
      await Future<void>.delayed(Duration.zero);

      // c1이 아직 응답 전이므로 c2는 대기 중이어야 한다
      expect(repo.calls, ['complete c1']);

      repo.releaseAll();
      await repo.drain();

      expect(repo.calls, ['complete c1', 'complete c2']);
    });
  });

  group('보상 규칙은 그대로다', () {
    test('처음 체크하면 보상, 해제 후 재체크는 보상 없음', () async {
      final (:container, :repo) = setUp();
      final notifier = container.read(childRoutineProvider.notifier);

      expect(notifier.toggle(routine: routine, card: c1), isTrue);
      await repo.drain();
      expect(notifier.toggle(routine: routine, card: c1), isFalse); // 해제
      await repo.drain();
      expect(notifier.toggle(routine: routine, card: c1), isFalse); // 재체크
      await repo.drain();

      expect(container.read(childRoutineProvider).rewarded, contains('c1'));
    });
  });
}

/// 서버 대신 호출을 기록하는 가짜 저장소.
///
/// [hold]가 true면 응답을 잡아뒀다가 [releaseAll]로 한 번에 푼다 —
/// 직렬화(앞 요청 완료 전 뒤 요청 미발송)를 검증하기 위해서다.
class _FakeStepRepo extends StepProgressRepository {
  _FakeStepRepo({required this.accept}) : super(dio: Dio());

  bool accept;
  bool hold = false;
  final calls = <String>[];
  final _pending = <Completer<void>>[];

  @override
  Future<bool> complete({required String routineId, required String stepId}) =>
      _record('complete $stepId');

  @override
  Future<bool> cancel({required String routineId, required String stepId}) =>
      _record('cancel $stepId');

  Future<bool> _record(String call) async {
    calls.add(call);
    if (hold) {
      final completer = Completer<void>();
      _pending.add(completer);
      await completer.future;
    }
    return accept;
  }

  void releaseAll() {
    for (final c in _pending) {
      if (!c.isCompleted) c.complete();
    }
    _pending.clear();
  }

  /// 대기 중인 동기화가 전부 끝날 때까지 이벤트 루프를 돌린다.
  Future<void> drain() async {
    for (var i = 0; i < 10; i++) {
      await Future<void>.delayed(Duration.zero);
    }
  }
}
