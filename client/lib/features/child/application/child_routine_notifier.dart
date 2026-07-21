import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/models/routine.dart';
import '../../guardian/application/routine_notifier.dart';
import '../data/step_progress_repository.dart';

/// 아이 모드에서 보는 일과 상태.
///
/// 완료 여부와 **보상을 이미 받았는지**를 따로 기억한다.
/// 체크를 풀었다가 다시 눌렀을 때 또 축하하면 보상이 가벼워지기 때문이다.
class ChildRoutineState {
  const ChildRoutineState({
    this.completed = const {},
    this.rewarded = const {},
  });

  /// 완료 체크된 카드 id. 해제하면 빠진다.
  final Set<String> completed;

  /// 보상을 이미 보여준 카드 id. **해제해도 남는다.**
  final Set<String> rewarded;

  ChildRoutineState copyWith({
    Set<String>? completed,
    Set<String>? rewarded,
  }) {
    return ChildRoutineState(
      completed: completed ?? this.completed,
      rewarded: rewarded ?? this.rewarded,
    );
  }

  bool isCompleted(String cardId) => completed.contains(cardId);
}

final childRoutineProvider =
    NotifierProvider<ChildRoutineNotifier, ChildRoutineState>(
  ChildRoutineNotifier.new,
);

class ChildRoutineNotifier extends Notifier<ChildRoutineState> {
  @override
  ChildRoutineState build() => const ChildRoutineState();

  /// 아이가 보는 일과. 보호자가 방금 만든 것을 그대로 쓴다.
  Routine? get routine => ref.read(routineFlowProvider).routine;

  /// 카드 체크를 토글하고, **보상을 띄워야 하면 true**를 돌려준다.
  ///
  /// 보상 조건은 두 가지를 모두 만족할 때다.
  /// 1. 방금 완료로 바뀌었다 (해제가 아니다)
  /// 2. 이 카드로 보상을 받은 적이 없다
  ///
  /// **서버 반영은 기다리지 않는다.** 아동이 누르는 즉시 체크가 보여야 한다.
  /// 네트워크를 기다리면 눌렀는데 반응이 없는 것처럼 느껴진다.
  bool toggle(String cardId) {
    final isNowCompleted = !state.isCompleted(cardId);

    final completed = Set<String>.from(state.completed);
    isNowCompleted ? completed.add(cardId) : completed.remove(cardId);

    final shouldReward = isNowCompleted && !state.rewarded.contains(cardId);

    state = state.copyWith(
      completed: completed,
      // 보상을 띄우는 순간 이력에 남긴다. 해제해도 지우지 않는다.
      rewarded: shouldReward
          ? {...state.rewarded, cardId}
          : state.rewarded,
    );

    // 별 지급·회수를 뒤에서 처리한다. 실패해도 화면은 이미 바뀐 뒤다.
    unawaited(_syncToServer(cardId, isCompleted: isNowCompleted));

    return shouldReward;
  }

  /// 별을 서버에 반영한다. 실패는 repository가 흡수한다.
  Future<void> _syncToServer(String cardId, {required bool isCompleted}) async {
    final routineId = routine?.id;
    // 로컬 카드는 서버에 없다
    if (routineId == null || routineId.isEmpty || routineId == 'local') return;

    final repo = ref.read(stepProgressRepositoryProvider);
    if (isCompleted) {
      await repo.complete(routineId: routineId, stepId: cardId);
    } else {
      await repo.cancel(routineId: routineId, stepId: cardId);
    }
  }

  /// 새 일과를 시작할 때 초기화한다.
  void reset() => state = const ChildRoutineState();
}
