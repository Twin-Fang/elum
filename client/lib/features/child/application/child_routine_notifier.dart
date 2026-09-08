import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/models/action_card.dart';
import '../../../shared/models/routine.dart';
import '../../guardian/data/routine_repository.dart';
import '../data/progress_store.dart';
import '../data/step_progress_repository.dart';
import '../domain/routine_progress_record.dart';

/// 아이 모드에서 보는 일과 진행 상태 (오프라인 퍼스트, 이슈 #140).
///
/// **기기가 진실이다.** [progress]에 기록이 있는 일과는 서버 `completed`를 무시하고
/// 기록을 보여준다. 기록이 없는 일과만 서버 값을 쓴다. 서버 반영이 안 끝난 일과는
/// [pending]에 남아 있다가 다음 기회에 다시 전송된다.
class ChildRoutineState {
  const ChildRoutineState({this.progress = const {}, this.pending = const {}});

  /// routineId → 로컬 진행 기록.
  final Map<String, RoutineProgressRecord> progress;

  /// 서버 반영이 아직 안 끝난 routineId.
  final Set<String> pending;

  ChildRoutineState copyWith({
    Map<String, RoutineProgressRecord>? progress,
    Set<String>? pending,
  }) {
    return ChildRoutineState(
      progress: progress ?? this.progress,
      pending: pending ?? this.pending,
    );
  }

  /// 화면에 체크로 보이는가. 로컬 기록이 있으면 그것이, 없으면 서버 값이 기준이다.
  bool isChecked(String routineId, ActionCard card) {
    final record = progress[routineId];
    if (record == null) return card.completed;
    return record.completed.contains(card.id);
  }

  bool hasRewarded(String routineId, String cardId) =>
      progress[routineId]?.rewarded.contains(cardId) ?? false;
}

final childRoutineProvider =
    NotifierProvider<ChildRoutineNotifier, ChildRoutineState>(
      ChildRoutineNotifier.new,
    );

class ChildRoutineNotifier extends Notifier<ChildRoutineState> {
  /// 서버 전송 체인. 한 번에 하나씩, 큐에 넣은 순서대로 보낸다.
  Future<void> _syncChain = Future<void>.value();

  /// 체인에 이미 들어가 대기 중인 routineId. 같은 일과를 연타해도 한 번만 줄 선다 —
  /// 전송 시점에 최신 집합을 읽으므로 한 번이면 충분하다.
  final Set<String> _queued = {};

  @override
  ChildRoutineState build() => const ChildRoutineState();

  ProgressStore get _store => ref.read(progressStoreProvider);

  /// 앱 시작 시 저장된 기록·대기열을 복원하고 곧바로 동기화를 시도한다.
  Future<void> hydrate() async {
    final pending = _store.pending;
    final progress = <String, RoutineProgressRecord>{};
    for (final id in pending) {
      final record = _store.load(id);
      if (record != null) progress[id] = record;
    }
    state = state.copyWith(progress: progress, pending: pending);
    syncPending();
  }

  /// 카드 체크를 토글하고, **보상을 띄워야 하면 true**를 돌려준다.
  ///
  /// 순서 제한은 없다 — 서버 일괄 반영 API가 순서를 검사하지 않는다(스펙 확정).
  /// 즉시 로컬에 반영·저장하고 서버 전송은 뒤에서 따라온다.
  ///
  /// 보상은 "처음 완료로 바뀔 때" 한 번만이다. 해제했다 다시 체크해도 안 준다.
  bool toggle({required Routine routine, required ActionCard card}) {
    final current = state.progress[routine.id] ?? _fromServer(routine);
    final wasChecked = current.completed.contains(card.id);

    final completed = Set<String>.from(current.completed);
    wasChecked ? completed.remove(card.id) : completed.add(card.id);

    final shouldReward = !wasChecked && !current.rewarded.contains(card.id);
    final record = current.copyWith(
      completed: completed,
      rewarded: shouldReward
          ? {...current.rewarded, card.id}
          : current.rewarded,
    );

    final isServerRoutine = routine.id.isNotEmpty && routine.id != 'local';
    state = state.copyWith(
      progress: {...state.progress, routine.id: record},
      pending: isServerRoutine ? {...state.pending, routine.id} : state.pending,
    );

    // 저장은 기다리지 않는다 — 아동이 누르는 즉시 화면이 바뀌어야 한다
    unawaited(_persist(routine.id, record));
    if (isServerRoutine) _enqueue(routine.id);

    return shouldReward;
  }

  /// 대기열 전체를 다시 전송한다. 앱 시작·복귀·온라인 전환 시 호출된다.
  void syncPending() {
    for (final id in state.pending) {
      _enqueue(id);
    }
  }

  /// 로컬 기록이 없을 때의 출발점 — 서버가 준 완료 상태를 그대로 옮긴다.
  RoutineProgressRecord _fromServer(Routine routine) => RoutineProgressRecord(
    completed: routine.steps.where((s) => s.completed).map((s) => s.id).toSet(),
  );

  Future<void> _persist(String routineId, RoutineProgressRecord record) async {
    await _store.save(routineId, record);
    await _store.setPending(state.pending);
  }

  void _enqueue(String routineId) {
    if (!_queued.add(routineId)) return;
    _syncChain = _syncChain.then((_) => _sync(routineId));
  }

  Future<void> _sync(String routineId) async {
    _queued.remove(routineId);
    final record = state.progress[routineId];
    if (record == null) {
      await _clearPending(routineId);
      return;
    }

    // 전송한 집합을 기억해 둔다. 응답을 기다리는 동안 또 체크됐으면 그건 아직
    // 서버에 없는 것이므로 대기열에서 빼지 않는다.
    final sent = Set<String>.from(record.completed);
    final outcome = await ref
        .read(stepProgressRepositoryProvider)
        .syncProgress(routineId: routineId, completedStepIds: sent);

    // 응답을 기다리는 동안 provider가 내려갔을 수 있다(테스트 teardown 등).
    if (!ref.mounted) return;

    switch (outcome) {
      case SyncOutcome.accepted:
        final latest = state.progress[routineId]?.completed ?? const <String>{};
        if (setEquals(latest, sent)) {
          await _clearPending(routineId);
        } else {
          // 전송 중 바뀌었다 — 최신 집합을 다시 보낸다
          _enqueue(routineId);
        }
        _refreshLists();
      case SyncOutcome.rejected:
        // 서버가 이 상태를 거부했다(승인 전·삭제 등). 기기 기록을 버리고 서버 값으로 돌아간다.
        debugPrint('[sync] 서버 거부 — 로컬 기록 폐기: $routineId');
        final progress = Map<String, RoutineProgressRecord>.from(state.progress)
          ..remove(routineId);
        state = state.copyWith(progress: progress);
        await _store.remove(routineId);
        await _clearPending(routineId);
        _refreshLists();
      case SyncOutcome.unreachable:
        // 그대로 둔다. 다음 트리거(복귀·온라인 전환·조작)에서 다시 보낸다.
        debugPrint('[sync] 서버에 닿지 못함 — 대기열 유지: $routineId');
    }
  }

  Future<void> _clearPending(String routineId) async {
    if (!state.pending.contains(routineId)) return;
    state = state.copyWith(pending: {...state.pending}..remove(routineId));
    await _store.setPending(state.pending);
  }

  /// 목록이 서버 진실(진행률·별)을 다시 읽게 한다.
  void _refreshLists() {
    ref.invalidate(todayRoutinesProvider);
    ref.invalidate(myRoutinesProvider);
  }

  /// 새 일과를 시작할 때 화면 상태만 초기화한다. 저장소는 건드리지 않는다.
  void reset() => state = const ChildRoutineState();
}
