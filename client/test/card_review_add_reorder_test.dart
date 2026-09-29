import 'package:elum/core/network/app_failure.dart';
import 'package:elum/features/guardian/application/routine_notifier.dart';
import 'package:elum/features/guardian/data/routine_repository.dart';
import 'package:elum/shared/models/action_card.dart';
import 'package:elum/shared/models/routine.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/test_storage.dart';

/// 카드확인의 카드 추가와 순서 변경 (#444 · 시안 1197:6044 / 1197:5798).
///
/// **서버 순서 API 는 카드 전체를 요구한다** (`steps.size() != stepIds.size()` 면 400).
/// 그런데 카드 X 로 뺀 카드는 저장하기 전까지 서버에 남아 있다(#405). 순서를 바로
/// 보내면 늘 실패하므로 순서는 로컬에 두고 저장하기가 삭제 다음에 보낸다.
///
/// 카드 추가는 반대로 **즉시 서버로 간다** — 새 카드의 id 를 서버가 줘야 이후에
/// 고치고 옮길 수 있다.
void main() {
  const cards = [
    ActionCard(id: 'c1', title: '옷을 입어요', description: '설명1', stepOrder: 1),
    ActionCard(id: 'c2', title: '우산을 챙겨요', description: '설명2', stepOrder: 2),
    ActionCard(id: 'c3', title: '신발을 신어요', description: '설명3', stepOrder: 3),
  ];

  Routine routineOf(String status) =>
      Routine(id: 'r1', title: '비 오는 날 등교', status: status, steps: cards);

  ({ProviderContainer container, _Repo repo, RoutineFlowNotifier notifier})
  setUpFlow(String status) {
    final repo = _Repo();
    final container = ProviderContainer(
      overrides: [
        testStorageOverride(onboardingCompleted: true),
        routineRepositoryProvider.overrideWithValue(repo),
      ],
    );
    addTearDown(container.dispose);
    final notifier = container.read(routineFlowProvider.notifier)
      ..loadExisting(routineOf(status));
    return (container: container, repo: repo, notifier: notifier);
  }

  List<String> idsOf(ProviderContainer c) => [
    for (final s in c.read(routineFlowProvider).routine!.steps) s.id,
  ];

  group('카드 추가', () {
    test('서버가 준 새 카드가 맨 뒤에 붙는다', () async {
      final f = setUpFlow('PENDING_REVIEW');

      final failure = await f.notifier.addStep(
        title: '가방을 챙겨요',
        description: '책가방을 챙겨요',
      );

      expect(failure, isNull);
      expect(idsOf(f.container), ['c1', 'c2', 'c3', 'n1']);
      final added = f.container.read(routineFlowProvider).routine!.steps.last;
      expect(added.title, '가방을 챙겨요', reason: '서버 응답에는 제목이 없어 입력한 제목을 되살린다');
      expect(added.description, '책가방을 챙겨요');
    });

    test('그림 생성을 요청하지 않는다 — 시안에 선택지가 없다', () async {
      final f = setUpFlow('PENDING_REVIEW');

      await f.notifier.addStep(title: '가방', description: '책가방');

      expect(f.repo.addCalls, 1);
      expect(f.repo.lastAdd, (title: '가방', description: '책가방'));
    });

    test('뺀 카드는 서버 목록에 남아 있어도 되살아나지 않는다', () async {
      final f = setUpFlow('PENDING_REVIEW');
      f.notifier.removeStep('c2');

      await f.notifier.addStep(title: '가방', description: '책가방');

      // 서버 응답은 c1·c2·c3·n1 이지만 c2 는 보호자가 이미 뺐다
      expect(idsOf(f.container), ['c1', 'c3', 'n1']);
    });

    test('실패하면 목록을 그대로 두고 이유를 돌려준다', () async {
      final f = setUpFlow('PENDING_REVIEW');
      f.repo.failAdd = true;

      final failure = await f.notifier.addStep(title: '가방', description: '책가방');

      expect(failure, isNotNull);
      expect(idsOf(f.container), ['c1', 'c2', 'c3']);
    });

    test('응답에 새 카드가 없으면 실패로 본다 — 목록을 만들어 내지 않는다', () async {
      final f = setUpFlow('PENDING_REVIEW');
      f.repo.returnNoNewCard = true;

      final failure = await f.notifier.addStep(title: '가방', description: '책가방');

      expect(failure, isNotNull);
      expect(idsOf(f.container), ['c1', 'c2', 'c3']);
    });
  });

  group('카드 10장 상한 (서버 STEP_MAX_COUNT)', () {
    /// 서버가 카드 [n]장을 가진 일과. 화면 목록과 서버 목록이 같다.
    List<ActionCard> many(int n) => [
      for (var i = 1; i <= n; i++)
        ActionCard(id: 'k$i', title: '카드$i', description: '설명$i', stepOrder: i),
    ];

    ({ProviderContainer container, _Repo repo, RoutineFlowNotifier notifier})
    setUpMany(int n) {
      final repo = _Repo()..serverSteps = many(n);
      final container = ProviderContainer(
        overrides: [
          testStorageOverride(onboardingCompleted: true),
          routineRepositoryProvider.overrideWithValue(repo),
        ],
      );
      addTearDown(container.dispose);
      final notifier = container.read(routineFlowProvider.notifier)
        ..loadExisting(
          Routine(id: 'r1', status: 'PENDING_REVIEW', steps: many(n)),
        );
      return (container: container, repo: repo, notifier: notifier);
    }

    test('화면 9장이어도 뺀 카드가 서버에 남아 10장이면 먼저 지우고 추가한다', () async {
      final f = setUpMany(10);
      f.notifier.removeStep('k3'); // 화면 9장, 서버는 아직 10장 — 서버는 11번째를 거절한다

      final failure = await f.notifier.addStep(title: '새 카드', description: '설명');

      expect(failure, isNull);
      // 지우기가 추가보다 먼저다 — 안 그러면 서버가 상한으로 거절한다
      expect(f.repo.log, ['delete:k3', 'add']);
      expect(idsOf(f.container).contains('k3'), isFalse);
      expect(idsOf(f.container).length, 10);
    });

    test('뺀 카드가 없으면 지우지 않고 그대로 추가를 부른다 — 거절은 서버가 알린다', () async {
      final f = setUpMany(10);

      await f.notifier.addStep(title: '새 카드', description: '설명');

      expect(f.repo.log, ['add']);
    });

    test('서버 목록이 10장 미만이면 뺀 카드를 미리 지우지 않는다 (저장하기를 기다린다)', () async {
      final f = setUpMany(6);
      f.notifier.removeStep('k3');

      await f.notifier.addStep(title: '새 카드', description: '설명');

      expect(f.repo.log, ['add'], reason: '나가기 팝업의 "저장하기를 눌러야 빠져요" 를 지킨다');
    });

    test('미리 지우다 실패하면 추가하지 않고 이유를 돌려준다', () async {
      final f = setUpMany(10);
      f.repo.failDelete = true;
      f.notifier.removeStep('k3');

      final failure = await f.notifier.addStep(title: '새 카드', description: '설명');

      expect(failure, isNotNull);
      expect(f.repo.log, ['delete:k3'], reason: '실패하면 추가를 부르지 않는다');
      expect(idsOf(f.container).length, 9, reason: '화면은 그대로 9장');
    });

    test('지운 카드는 저장하기가 다시 지우러 가지 않는다', () async {
      final f = setUpMany(10);
      f.notifier.removeStep('k3');
      await f.notifier.addStep(title: '새 카드', description: '설명');
      f.repo.log.clear();

      await f.notifier.save();

      expect(f.repo.log.where((l) => l.startsWith('delete')), isEmpty);
    });
  });

  group('순서 변경', () {
    test('카드를 옮기면 차례가 바뀌고 번호가 다시 매겨진다', () {
      final f = setUpFlow('PENDING_REVIEW');

      // 첫 카드를 맨 뒤로 (ReorderableListView 는 아래로 옮길 때 제거 전 위치를 준다)
      f.notifier.moveStep(0, 3);

      final steps = f.container.read(routineFlowProvider).routine!.steps;
      expect([for (final s in steps) s.id], ['c2', 'c3', 'c1']);
      expect([for (final s in steps) s.stepOrder], [1, 2, 3]);
    });

    test('범위를 벗어난 자리는 무시한다', () {
      final f = setUpFlow('PENDING_REVIEW');

      f.notifier
        ..moveStep(-1, 1)
        ..moveStep(0, 9)
        ..moveStep(7, 0);

      expect(idsOf(f.container), ['c1', 'c2', 'c3']);
    });

    test('옮기는 동안에는 서버를 부르지 않는다', () {
      final f = setUpFlow('PENDING_REVIEW');

      f.notifier.moveStep(0, 3);

      expect(f.repo.log, isEmpty);
    });

    test('✕ 로 나오면 들어오기 전 순서로 돌아간다', () {
      final f = setUpFlow('PENDING_REVIEW');
      final snapshot = f.notifier.snapshotOrder();

      f.notifier
        ..moveStep(0, 3)
        ..restoreOrder(snapshot);

      expect(idsOf(f.container), ['c1', 'c2', 'c3']);
    });

    test('되돌린 뒤 저장하면 순서 API 를 부르지 않는다', () async {
      final f = setUpFlow('CONFIRMED');
      final snapshot = f.notifier.snapshotOrder();

      f.notifier
        ..moveStep(0, 3)
        ..restoreOrder(snapshot);
      await f.notifier.save();

      expect(f.repo.reorderCalls, isEmpty);
    });
  });

  group('저장하기가 순서를 보낸다', () {
    test('삭제 → 순서 → 확정 순서로 부른다', () async {
      final f = setUpFlow('PENDING_REVIEW');

      f.notifier
        ..removeStep('c2')
        ..moveStep(0, 2); // [c3? ] 남은 카드 [c1,c3] 를 [c3,c1] 로
      final failure = await f.notifier.save();

      expect(failure, isNull);
      expect(f.repo.log, ['delete:c2', 'reorder:c3,c1', 'confirm']);
    });

    test('순서 API 에는 화면에 남은 카드 전체를 보낸다', () async {
      final f = setUpFlow('CONFIRMED');

      f.notifier.moveStep(2, 0); // c3 를 맨 앞으로
      await f.notifier.save();

      expect(f.repo.reorderCalls, [
        ['c3', 'c1', 'c2'],
      ]);
    });

    test('순서를 안 바꿨으면 순서 API 를 부르지 않는다', () async {
      final f = setUpFlow('PENDING_REVIEW');

      await f.notifier.save();

      expect(f.repo.reorderCalls, isEmpty);
      expect(f.repo.confirmCalls, 1);
    });

    test('이미 저장한 일과도 순서는 보내고 확정은 하지 않는다', () async {
      final f = setUpFlow('CONFIRMED');

      f.notifier.moveStep(0, 2);
      await f.notifier.save();

      expect(f.repo.reorderCalls, hasLength(1));
      expect(f.repo.confirmCalls, 0);
    });

    test('순서 저장이 실패하면 확정하지 않고 이유를 돌려준다', () async {
      final f = setUpFlow('PENDING_REVIEW');
      f.repo.failReorder = true;

      f.notifier.moveStep(0, 2);
      final failure = await f.notifier.save();

      expect(failure, isNotNull);
      expect(f.repo.confirmCalls, 0, reason: '순서가 어긋난 채 이룸이에게 가면 안 된다');
    });

    test('다시 누르면 실패했던 순서를 다시 보낸다', () async {
      final f = setUpFlow('PENDING_REVIEW');
      f.repo.failReorder = true;
      f.notifier.moveStep(0, 2);
      await f.notifier.save();

      f.repo.failReorder = false;
      final failure = await f.notifier.save();

      expect(failure, isNull);
      expect(f.repo.reorderCalls, hasLength(2));
      expect(f.repo.confirmCalls, 1);
    });

    test('성공하면 다음 저장은 순서를 다시 보내지 않는다', () async {
      final f = setUpFlow('CONFIRMED');
      f.notifier.moveStep(0, 2);
      await f.notifier.save();

      await f.notifier.save();

      expect(f.repo.reorderCalls, hasLength(1));
    });
  });
}

class _Repo implements RoutineRepository {
  final log = <String>[];
  final reorderCalls = <List<String>>[];
  var confirmCalls = 0;
  var addCalls = 0;
  ({String title, String description})? lastAdd;

  var failAdd = false;
  var failDelete = false;
  var returnNoNewCard = false;

  /// 서버가 가진 카드 전체. 화면에서 뺀 것도 들어 있다.
  List<ActionCard> serverSteps = const [
    ActionCard(id: 'c1', title: '옷을 입어요', description: '설명1', stepOrder: 1),
    ActionCard(id: 'c2', title: '우산을 챙겨요', description: '설명2', stepOrder: 2),
    ActionCard(id: 'c3', title: '신발을 신어요', description: '설명3', stepOrder: 3),
  ];
  var failReorder = false;

  @override
  Future<({Routine routine, AppFailure? failure})> addStep(
    Routine routine, {
    required String title,
    required String description,
  }) async {
    addCalls++;
    log.add('add');
    lastAdd = (title: title, description: description);
    if (failAdd) {
      return (
        routine: routine,
        failure: const AppFailure(fault: NetworkFault.offline),
      );
    }
    if (returnNoNewCard) return (routine: routine, failure: null);
    // 서버 응답에는 제목이 없다 (RoutineStep 에 title 컬럼이 없다)
    final added = ActionCard(
      id: 'n1',
      description: description,
      stepOrder: serverSteps.length + 1,
    );
    // **서버는 보호자가 화면에서 뺀 카드도 아직 갖고 있다** (저장하기 전이라 삭제 전이다).
    // 그래서 응답은 화면 목록이 아니라 서버 목록 전체 + 새 카드다.
    return (
      routine: routine.copyWith(steps: [...serverSteps, added]),
      failure: null,
    );
  }

  @override
  Future<AppFailure?> deleteStep(String routineId, String stepId) async {
    log.add('delete:$stepId');
    if (failDelete) return const AppFailure(fault: NetworkFault.offline);
    // 서버에서 지워졌으니 이후 응답 목록에서도 빠진다
    serverSteps = [
      for (final s in serverSteps)
        if (s.id != stepId) s,
    ];
    return null;
  }

  @override
  Future<AppFailure?> reorderSteps(String routineId, List<String> stepIds) async {
    reorderCalls.add(stepIds);
    log.add('reorder:${stepIds.join(',')}');
    return failReorder ? const AppFailure(fault: NetworkFault.offline) : null;
  }

  @override
  Future<Routine> confirm(Routine routine) async {
    confirmCalls++;
    log.add('confirm');
    return routine.copyWith(status: 'CONFIRMED');
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
