import 'dart:async';

import 'package:elum/features/guardian/data/routine_repository.dart';
import 'package:elum/features/guardian/domain/routine_suggestion.dart';
import 'package:elum/shared/models/routine.dart';
import 'package:elum/shared/models/support_goal.dart';

import 'fake_reward_api.dart';

/// 서버를 타지 않는 일과 저장소. 레이아웃만 보는 테스트가 쓴다 (목록은 provider override 가 정한다).
class StubRoutineRepository with FakeRewardApi implements RoutineRepository {
  @override
  Future<List<Routine>> getMyRoutines() async => const [];

  @override
  Future<List<Routine>> getTodayRoutines() async => const [];

  @override
  Future<List<Routine>> getPastRoutines() async => const [];

  @override
  Future<List<RoutineSuggestion>> getSuggestions() async => const [];

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// 일과 생성 요청이 끝나지 않는 저장소: 로딩 연출이 계속 도는 상태를 만든다
class PendingRoutineRepository extends StubRoutineRepository {
  @override
  Future<Routine> createRoutine({
    required String rawInputText,
    required Set<SupportGoal> goals,
    List<String>? answers,
    String? rewardText,
    String? rewardPresetKey,
    String? idempotencyKey,
  }) => Completer<Routine>().future;
}
