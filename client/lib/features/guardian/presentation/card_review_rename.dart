import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/state/busy_state_mixin.dart';
import '../application/routine_notifier.dart';
import 'routine_rename_flow.dart';

/// 카드확인: 제목 옆 연필 > 이름 시트 > 저장 > 흐름의 일과 제목 바꾸기 (고치던 카드·순서는 그대로)
mixin CardReviewRename<T extends ConsumerStatefulWidget>
    on ConsumerState<T>, BusyStateMixin<T> {
  Future<void> renameRoutineInFlow() async {
    final routine = ref.read(routineFlowProvider).routine;
    if (routine == null || routine.id.isEmpty) return;
    final renamed = await renameRoutineWithSheet(
      context,
      ref,
      routineId: routine.id,
      currentTitle: routine.displayTitle,
      runBusy: runBusy,
    );
    if (renamed == null || !mounted) return;
    ref.read(routineFlowProvider.notifier).applyRenamedTitle(renamed.title);
  }
}
