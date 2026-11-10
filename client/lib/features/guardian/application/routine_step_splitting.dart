import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/models/routine.dart';
import '../domain/card_split.dart';
import 'routine_flow_state.dart';
import 'routine_providers.dart';
import 'routine_step_editing.dart';

/// 카드 나누기 반영: 원래 카드 자리에 새 카드들을 끼움 (카드 수정과 같은 화면 상태를 씀)
mixin RoutineStepSplitting on Notifier<RoutineFlowState>, RoutineStepEditing {
  /// [splitRoutine](서버가 돌려준 일과)에서 새로 생긴 카드만 [stepId] 자리에 넣고 번호를 다시 매김
  ///
  /// 서버 목록을 통째로 쓰지 않음: 화면에서 이미 뺀 카드(저장 전이라 서버에 남음)가 되살아나기 때문.
  /// 서버 응답에 카드 제목이 비어 오면 [drafts] 의 제목으로 채움. 반영한 새 카드 수를 돌려주고, 못 하면 0
  int applySplitSteps({
    required String stepId,
    required List<CardSplitDraft> drafts,
    required Routine splitRoutine,
  }) {
    final routine = state.routine;
    if (routine == null) return 0;
    final splitIndex = routine.steps.indexWhere((step) => step.id == stepId);
    if (splitIndex < 0) return 0;

    // 새 카드 = 서버 응답에서 (화면 카드 + 뺀 카드)에 없던 것 (응답 순서 = 나눈 순서)
    final knownStepIds = {for (final step in routine.steps) step.id, ...pendingRemovedStepIds};
    final addedSteps = [
      for (final step in splitRoutine.steps)
        if (!knownStepIds.contains(step.id)) step,
    ];
    if (addedSteps.isEmpty) return 0;

    final titledSteps = [
      for (var index = 0; index < addedSteps.length; index++)
        if (addedSteps[index].title.isEmpty && index < drafts.length)
          addedSteps[index].copyWith(title: drafts[index].title)
        else
          addedSteps[index],
    ];
    final mergedSteps = [
      ...routine.steps.take(splitIndex),
      ...titledSteps,
      ...routine.steps.skip(splitIndex + 1),
    ];
    state = state.copyWith(
      routine: routine.copyWith(
        steps: [
          // 번호는 자리다: 자리대로 다시 매김
          for (var index = 0; index < mergedSteps.length; index++) mergedSteps[index].copyWith(stepOrder: index + 1),
        ],
      ),
    );
    ref.refreshRoutines();
    return titledSteps.length;
  }
}
