import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/models/action_card.dart';
import '../../../shared/models/routine.dart';
import '../../guardian/data/routine_repository.dart';
import '../data/step_progress_repository.dart';

/// 아이 모드에서 보는 일과 상태.
///
/// 서버 `completed` 위에 **로컬 표시를 덮어쓰는** 구조다. 아동이 누르는 즉시
/// 반응해야 하므로 서버 응답을 기다리지 않고 먼저 표시하고, 서버가 거부하면 걷어낸다.
///
/// 완료 여부와 **보상을 이미 받았는지**를 따로 기억한다.
/// 체크를 풀었다가 다시 눌렀을 때 또 축하하면 보상이 가벼워지기 때문이다.
class ChildRoutineState {
  const ChildRoutineState({
    this.completed = const {},
    this.uncompleted = const {},
    this.rewarded = const {},
  });

  /// 로컬에서 완료로 표시한 카드 id.
  final Set<String> completed;

  /// 서버에는 완료로 남아 있지만 로컬에서 해제한 카드 id.
  /// 앱을 다시 열면 로컬 상태 없이 서버 `completed=true`만 있는데, 그걸 풀 때 필요하다.
  final Set<String> uncompleted;

  /// 보상을 이미 보여준 카드 id. **해제해도 남는다.**
  final Set<String> rewarded;

  ChildRoutineState copyWith({
    Set<String>? completed,
    Set<String>? uncompleted,
    Set<String>? rewarded,
  }) {
    return ChildRoutineState(
      completed: completed ?? this.completed,
      uncompleted: uncompleted ?? this.uncompleted,
      rewarded: rewarded ?? this.rewarded,
    );
  }

  /// 로컬에서 완료로 표시했는가. 서버 값은 보지 않는다 — 화면 판단은 [isChecked]를 쓴다.
  bool isCompleted(String cardId) => completed.contains(cardId);

  /// 화면에 체크로 보이는가. 로컬 표시가 있으면 그것이, 없으면 서버 값이 기준이다.
  bool isChecked(ActionCard card) {
    if (completed.contains(card.id)) return true;
    if (uncompleted.contains(card.id)) return false;
    return card.completed;
  }
}

final childRoutineProvider =
    NotifierProvider<ChildRoutineNotifier, ChildRoutineState>(
      ChildRoutineNotifier.new,
    );

class ChildRoutineNotifier extends Notifier<ChildRoutineState> {
  /// 서버 동기화 체인. **앞 요청이 끝난 뒤에만 다음을 보낸다.**
  ///
  /// 서버가 단계 순서를 검사하므로, 요청이 뒤섞여 도착하면 앞 단계가 아직
  /// 저장되지 않은 채 뒤 단계가 거부된다. 탭 순서가 곧 서버 도착 순서여야 한다.
  Future<void> _syncChain = Future<void>.value();

  @override
  ChildRoutineState build() => const ChildRoutineState();

  /// 지금 이 카드를 누르면 상태가 바뀌는가 — 체크 버튼 활성 조건.
  ///
  /// 서버(`RoutineService`)와 **같은 규칙**을 화면이 먼저 지킨다.
  /// - 완료: 앞 단계가 전부 체크돼 있어야 한다 (아니면 서버가 409)
  /// - 해제: 뒤 단계가 하나도 체크돼 있지 않아야 한다 (아니면 서버가 409)
  ///
  /// 이걸 안 지키면 화면은 체크됐는데 서버는 거부한 상태가 생기고,
  /// 앱을 다시 열면 진행률이 되돌아간다 (이슈 #139 — 운영에서 100%→57%).
  bool canToggle({required Routine routine, required ActionCard card}) {
    if (state.isChecked(card)) {
      return !routine.steps.any(
        (s) => s.stepOrder > card.stepOrder && state.isChecked(s),
      );
    }
    return routine.steps
        .where((s) => s.stepOrder < card.stepOrder)
        .every(state.isChecked);
  }

  /// 카드 체크를 토글하고, **보상을 띄워야 하면 true**를 돌려준다.
  ///
  /// 순서 규칙에 걸리면 아무것도 바꾸지 않고 false다 — 호출부는 전후 상태를
  /// 비교해 "바뀌었는가"를 판단한다. 아동 화면이라 거부를 경고로 알리지 않는다.
  ///
  /// 보상 조건은 두 가지를 모두 만족할 때다.
  /// 1. 방금 완료로 바뀌었다 (해제가 아니다)
  /// 2. 이 카드로 보상을 받은 적이 없다
  ///
  /// **서버 반영은 기다리지 않는다.** 아동이 누르는 즉시 체크가 보여야 한다.
  bool toggle({required Routine routine, required ActionCard card}) {
    if (!canToggle(routine: routine, card: card)) return false;

    final isNowCompleted = !state.isChecked(card);
    _mark(card, checked: isNowCompleted);

    final shouldReward = isNowCompleted && !state.rewarded.contains(card.id);
    if (shouldReward) {
      // 보상을 띄우는 순간 이력에 남긴다. 해제해도 지우지 않는다.
      state = state.copyWith(rewarded: {...state.rewarded, card.id});
    }

    _enqueueSync(routine.id, card, isCompleted: isNowCompleted);
    return shouldReward;
  }

  /// 로컬 표시를 바꾼다. 서버 값과 다른 방향으로 갈 때만 override가 남는다.
  void _mark(ActionCard card, {required bool checked}) {
    final completed = Set<String>.from(state.completed);
    final uncompleted = Set<String>.from(state.uncompleted);
    if (checked) {
      completed.add(card.id);
      uncompleted.remove(card.id);
    } else {
      completed.remove(card.id);
      if (card.completed) uncompleted.add(card.id);
    }
    state = state.copyWith(completed: completed, uncompleted: uncompleted);
  }

  /// 로컬 표시를 걷어내 서버 값으로 되돌린다.
  void _unmark(ActionCard card) {
    state = state.copyWith(
      completed: Set<String>.from(state.completed)..remove(card.id),
      uncompleted: Set<String>.from(state.uncompleted)..remove(card.id),
    );
  }

  void _enqueueSync(
    String routineId,
    ActionCard card, {
    required bool isCompleted,
  }) {
    // 로컬 카드는 서버에 없다
    if (routineId.isEmpty || routineId == 'local') return;

    _syncChain = _syncChain.then(
      (_) => _sync(routineId, card, isCompleted: isCompleted),
    );
  }

  Future<void> _sync(
    String routineId,
    ActionCard card, {
    required bool isCompleted,
  }) async {
    final repo = ref.read(stepProgressRepositoryProvider);
    final accepted = isCompleted
        ? await repo.complete(routineId: routineId, stepId: card.id)
        : await repo.cancel(routineId: routineId, stepId: card.id);

    // 응답을 기다리는 동안 provider가 내려갔을 수 있다(화면 종료·테스트 teardown).
    // 죽은 ref를 건드리면 예외가 나므로 조용히 끝낸다.
    if (!ref.mounted) return;

    if (!accepted) {
      // 서버에 남지 않은 표시를 화면에 두면 앱을 다시 열 때 되돌아간다.
      // 로컬 표시를 걷어내 서버 값(재조회된 completed)이 그대로 보이게 한다.
      debugPrint(
        '[star] ${isCompleted ? "완료" : "취소"} 거부됨 — 화면 표시를 서버 값으로 되돌림: ${card.id}',
      );
      _unmark(card);
    }

    // 목록이 서버 진실(진행률·completed)을 다시 읽게 한다 — 성공·실패 모두.
    ref.invalidate(todayRoutinesProvider);
    ref.invalidate(myRoutinesProvider);
  }

  /// 새 일과를 시작할 때 초기화한다.
  void reset() => state = const ChildRoutineState();
}
