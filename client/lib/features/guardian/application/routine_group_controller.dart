import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/app_failure.dart';
import '../../../shared/models/routine.dart';
import '../data/routine_group_api.dart';
import '../domain/routine_group.dart';
import 'routine_providers.dart';

final routineGroupControllerProvider = Provider<RoutineGroupController>(
  (ref) => RoutineGroupController(ref),
);

/// 일과 묶음 동작 (#807): 만들기·넣기·빼기·순서·이름·복사·풀기·보내기 > 성공하면 목록 다시 받기
///
/// 규칙 2개를 여기서 지킨다: 묶음은 일과 2개 이상(1개가 되면 풀기), 일과 하나는 한 묶음에만(서버가 옮긴다).
class RoutineGroupController {
  RoutineGroupController(this._ref);

  final Ref _ref;

  RoutineGroupApi get _api => _ref.read(routineGroupApiProvider);

  /// 새 묶음. [routineIds] 순서가 묶음 순서
  Future<Attempt<RoutineGroup>> create(String name, List<String> routineIds) =>
      _refreshAfter(_api.create(name, routineIds));

  Future<Attempt<RoutineGroup>> rename(RoutineGroup group, String name) =>
      _refreshAfter(_api.rename(group.id, name));

  /// 순서 바꾸기 (같은 구성, 다른 순서)
  Future<Attempt<RoutineGroup>> reorder(
    RoutineGroup group,
    List<String> routineIds,
  ) => _refreshAfter(_api.replaceRoutines(group.id, routineIds));

  /// 묶음 맨 뒤에 일과를 넣는다 (이미 있으면 그대로)
  Future<Attempt<RoutineGroup>> add(
    RoutineGroup group,
    List<String> routineIds,
  ) {
    final next = [
      ...group.routineIds,
      for (final id in routineIds)
        if (!group.routineIds.contains(id)) id,
    ];
    return _refreshAfter(_api.replaceRoutines(group.id, next));
  }

  /// 묶음에서 일과 하나를 뺀다. 하나만 남으면 묶음을 푼다 → 풀렸으면 [RemoveOutcome.ungrouped]
  Future<({RemoveOutcome outcome, AppFailure? failure})> remove(
    RoutineGroup group,
    String routineId,
  ) async {
    final next = [
      for (final id in group.routineIds)
        if (id != routineId) id,
    ];
    if (next.length < RoutineGroup.minimumRoutineCount) {
      final failure = await ungroup(group);
      return (outcome: RemoveOutcome.ungrouped, failure: failure);
    }
    final replaced = await _refreshAfter(_api.replaceRoutines(group.id, next));
    return (outcome: RemoveOutcome.removed, failure: replaced.failure);
  }

  Future<Attempt<RoutineGroup>> copy(RoutineGroup group) =>
      _refreshAfter(_api.copy(group.id));

  /// 묶음 풀기. 안의 일과는 낱개로 일과관리에 남는다
  Future<AppFailure?> ungroup(RoutineGroup group) async {
    final failure = await _api.ungroup(group.id);
    if (failure == null) _ref.refreshRoutines();
    return failure;
  }

  /// 묶음째 오늘 보내기 (홈 오늘 일과·이룸이 홈이 함께 바뀐다)
  Future<Attempt<List<Routine>>> sendToday(RoutineGroup group) async {
    final sent = await _api.sendToday(group.id);
    if (sent.isOk) _ref.refreshRoutines();
    return sent;
  }

  Future<Attempt<RoutineGroup>> _refreshAfter(
    Future<Attempt<RoutineGroup>> call,
  ) async {
    final groupAttempt = await call;
    if (groupAttempt.isOk) _ref.refreshRoutines();
    return groupAttempt;
  }
}

/// 묶음에서 빼기의 결과: 빠지기만 했나, 하나 남아 묶음이 풀렸나
enum RemoveOutcome { removed, ungrouped }
