import 'package:elum/features/guardian/data/routine_repository.dart';
import 'package:elum/shared/models/routine.dart';

/// 보상·일과 정리 API(#148~150)의 무해한 기본 동작.
///
/// `RoutineRepository`에 메서드가 늘어날 때마다 테스트 fake 세 개를 똑같이
/// 고쳐야 하는 일을 막으려고 모았다. **이 기능을 검증하지 않는 fake**가
/// `with FakeRewardApi`로 가져다 쓴다. 실제로 보상 동작을 확인하는 테스트는
/// 여기 것을 덮어써서 쓴다.
mixin FakeRewardApi implements RoutineRepository {
  @override
  Future<({Routine routine, bool synced})> updateReward(
    Routine routine, {
    required String rewardText,
    String rewardPresetKey = '',
  }) async => (
    routine: routine.copyWith(
      rewardText: rewardText,
      rewardPresetKey: rewardPresetKey,
    ),
    synced: true,
  );

  @override
  Future<List<RecentReward>> getRecentRewards() async => const [];

  @override
  Future<List<Routine>> getPastRoutines() async => const [];

  @override
  Future<List<Routine>> getDraftRoutines() async => const [];

  @override
  Future<Routine?> duplicate(String routineId) async => null;

  @override
  Future<bool> delete(String routineId) async => true;
}
