import 'package:elum/core/network/app_failure.dart';
import 'package:elum/core/network/server_error.dart';
import 'package:elum/core/network/server_error_code.dart';
import 'package:elum/features/guardian/application/routine_notifier.dart';
import 'package:elum/features/guardian/data/routine_repository.dart';
import 'package:elum/shared/models/action_card.dart';
import 'package:elum/shared/models/routine.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/test_storage.dart';

/// 카드확인의 `저장하기` (이슈 #405).
///
/// 저장하기가 하는 일은 **일과의 상태에 따라 다르다.**
///
/// | 어디서 왔나 | 상태 | 저장하기가 하는 일 |
/// |---|---|---|
/// | 만들기 흐름 | `PENDING_REVIEW` | 뺀 카드를 지우고 **확정**한다 |
/// | 홈에서 편집 | `CONFIRMED` | 뺀 카드만 지운다. **확정하지 않는다** |
///
/// 전에는 어느 쪽이든 확정 API 를 불렀다. 서버는 임시저장만 확정할 수 있어서
/// 이미 저장한 일과를 편집하면 `ROUTINE_INVALID_STATUS` 로 거절했다
/// (운영 2026-09-24 14:08, 일과 `9657d0f6…`·`c293e85b…`).
///
/// 카드의 X 는 화면에서만 지운다 — "저장하기를 눌러야 빠져요"라고 나가기 팝업이
/// 약속한다. 그런데 그 약속을 지키는 코드가 없었다. 확정 API 는 본문 없이 상태만
/// 바꾸므로 **뺀 카드가 서버에 그대로 남아 이룸이 휴대폰에 떴다.**
void main() {
  const cards = [
    ActionCard(id: 'c1', description: '옷을 입어요', stepOrder: 1),
    ActionCard(id: 'c2', description: '우산을 챙겨요', stepOrder: 2),
    ActionCard(id: 'c3', description: '신발을 신어요', stepOrder: 3),
  ];

  Routine routineOf(String status) =>
      Routine(id: 'r1', title: '비 오는 날 등교', status: status, steps: cards);

  ({ProviderContainer container, _Repo repo}) setUpFlow(String status) {
    final repo = _Repo();
    final container = ProviderContainer(
      overrides: [
        testStorageOverride(onboardingCompleted: true),
        routineRepositoryProvider.overrideWithValue(repo),
      ],
    );
    addTearDown(container.dispose);
    container.read(routineFlowProvider.notifier).loadExisting(routineOf(status));
    return (container: container, repo: repo);
  }

  group('이미 저장한 일과를 편집해 저장한다', () {
    test('확정 API 를 부르지 않는다 — 서버가 409 로 거절하던 자리다', () async {
      final f = setUpFlow('CONFIRMED');
      final notifier = f.container.read(routineFlowProvider.notifier);

      notifier.removeStep('c2');
      final failure = await notifier.save();

      expect(failure, isNull);
      expect(f.repo.confirmCalls, 0, reason: 'CONFIRMED 는 확정 대상이 아니다');
    });

    test('뺀 카드가 서버에서 빠진다', () async {
      final f = setUpFlow('CONFIRMED');
      final notifier = f.container.read(routineFlowProvider.notifier);

      notifier
        ..removeStep('c2')
        ..removeStep('c3');
      await notifier.save();

      expect(f.repo.deletedStepIds, ['c2', 'c3']);
    });

    test('아무것도 빼지 않았으면 서버를 부르지 않는다 (E1)', () async {
      final f = setUpFlow('CONFIRMED');

      final failure = await f.container.read(routineFlowProvider.notifier).save();

      expect(failure, isNull);
      expect(f.repo.deletedStepIds, isEmpty);
      expect(f.repo.confirmCalls, 0);
    });

    test('COMPLETED 인 일과도 확정하지 않는다', () async {
      final f = setUpFlow('COMPLETED');
      final notifier = f.container.read(routineFlowProvider.notifier);

      notifier.removeStep('c2');
      await notifier.save();

      expect(f.repo.confirmCalls, 0);
      expect(f.repo.deletedStepIds, ['c2']);
    });
  });

  group('만들기 흐름에서 저장한다', () {
    test('뺀 카드를 지운 뒤 확정한다 — 순서가 중요하다', () async {
      final f = setUpFlow('PENDING_REVIEW');
      final notifier = f.container.read(routineFlowProvider.notifier);

      notifier.removeStep('c2');
      final failure = await notifier.save();

      expect(failure, isNull);
      expect(f.repo.deletedStepIds, ['c2']);
      expect(f.repo.confirmCalls, 1);
      // 확정이 삭제보다 먼저면, 확정하자마자 이룸이 화면에 뺀 카드가 잠깐 뜬다
      expect(f.repo.log, ['delete:c2', 'confirm']);
      expect(f.container.read(routineFlowProvider).step, RoutineFlowStep.done);
    });

    test('카드를 빼지 않아도 확정은 한다', () async {
      final f = setUpFlow('PENDING_REVIEW');

      await f.container.read(routineFlowProvider.notifier).save();

      expect(f.repo.deletedStepIds, isEmpty);
      expect(f.repo.confirmCalls, 1);
    });
  });

  group('실패해도 무엇이 남았는지 잃지 않는다', () {
    test('삭제가 실패하면 확정하지 않고 이유를 돌려준다 (E2)', () async {
      final f = setUpFlow('PENDING_REVIEW');
      final notifier = f.container.read(routineFlowProvider.notifier);
      f.repo.failDeleteOf = 'c3';

      notifier
        ..removeStep('c2')
        ..removeStep('c3');
      final failure = await notifier.save();

      expect(failure, isNotNull);
      expect(f.repo.confirmCalls, 0, reason: '뺀 카드가 남은 채 이룸이에게 가면 안 된다');
    });

    test('다시 누르면 성공한 삭제는 건너뛴다 (E2)', () async {
      final f = setUpFlow('PENDING_REVIEW');
      final notifier = f.container.read(routineFlowProvider.notifier);
      f.repo.failDeleteOf = 'c3';

      notifier
        ..removeStep('c2')
        ..removeStep('c3');
      await notifier.save();
      expect(f.repo.deletedStepIds, ['c2', 'c3']);

      // 두 번째 시도 — 이번에는 서버가 받아준다
      f.repo
        ..failDeleteOf = null
        ..deletedStepIds.clear();
      final failure = await notifier.save();

      expect(failure, isNull);
      expect(f.repo.deletedStepIds, ['c3'], reason: 'c2 는 이미 빠졌다');
      expect(f.repo.confirmCalls, 1);
    });

    test('이미 없는 카드는 빠진 것으로 본다 (E3)', () async {
      // 다른 휴대폰에서 먼저 지웠다 — 결과가 같으므로 실패로 보지 않는다
      final f = setUpFlow('PENDING_REVIEW');
      final notifier = f.container.read(routineFlowProvider.notifier);
      f.repo
        ..failDeleteOf = 'c2'
        ..deleteFailure = const AppFailure(
          fault: NetworkFault.none,
          server: ServerError(
            code: ServerErrorCode.routineStepNotFound,
            statusCode: 404,
          ),
        );

      notifier.removeStep('c2');
      final failure = await notifier.save();

      expect(failure, isNull);
      expect(f.repo.confirmCalls, 1);
    });

    test('확정이 실패하면 이유를 돌려주고 삭제를 다시 하지 않는다 (E6)', () async {
      final f = setUpFlow('PENDING_REVIEW');
      final notifier = f.container.read(routineFlowProvider.notifier);
      f.repo.failConfirm = true;

      notifier.removeStep('c2');
      expect(await notifier.save(), isNotNull);

      f.repo
        ..failConfirm = false
        ..deletedStepIds.clear();
      expect(await notifier.save(), isNull);
      expect(f.repo.deletedStepIds, isEmpty, reason: 'c2 는 앞서 빠졌다');
      expect(f.repo.confirmCalls, 2);
    });
  });

  test('다음 일과를 만들 때 지난번에 뺀 카드가 따라오지 않는다', () async {
    final f = setUpFlow('CONFIRMED');
    final notifier = f.container.read(routineFlowProvider.notifier);

    notifier.removeStep('c2');
    notifier.reset();
    notifier.loadExisting(routineOf('CONFIRMED'));
    await notifier.save();

    expect(f.repo.deletedStepIds, isEmpty);
  });
}

/// 무엇을 어떤 차례로 불렀는지 센다.
class _Repo implements RoutineRepository {
  final deletedStepIds = <String>[];
  final log = <String>[];
  var confirmCalls = 0;

  /// 이 id 를 지울 때만 실패한다. null 이면 전부 성공.
  String? failDeleteOf;
  AppFailure deleteFailure = const AppFailure(fault: NetworkFault.offline);
  var failConfirm = false;

  @override
  Future<AppFailure?> deleteStep(String routineId, String stepId) async {
    deletedStepIds.add(stepId);
    log.add('delete:$stepId');
    return stepId == failDeleteOf ? deleteFailure : null;
  }

  @override
  Future<Routine> confirm(Routine routine) async {
    confirmCalls++;
    log.add('confirm');
    if (failConfirm) throw StateError('확정 실패');
    return routine.copyWith(status: 'CONFIRMED');
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
