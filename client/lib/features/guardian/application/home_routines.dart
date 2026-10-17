import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/models/routine.dart';
import '../../child/application/child_routine_notifier.dart';
import 'routine_notifier.dart';
import 'routine_providers.dart';

/// 홈에 보여줄 일과 목록 — 방금 저장한 일과 + 서버 목록을 병합한다.
///
/// 서버 목록에 아직 없는 새 일과만 먼저 둔다. 서버가 같은 일과를 돌려주면
/// 최신 완료 상태를 쓴다 — 생성 직후의 이전 값이 다른 휴대폰의 체크를 가리지 않게 한다.
/// steps가 빈 일과는 보여줄 것이 없어 제외한다.
///
/// **흐름에 남은 일과가 임시저장(`PENDING_REVIEW`)이면 붙이지 않는다**.
/// 카드 확인에서 `나가기`로 끝내면 흐름에 그 일과가 남는데, 상태를 안 보고 붙이면
/// 아직 이룸이에게 보내지 않은 것이 오늘 일과 맨 앞에 뜬다. 오늘 일과는 저장(승인)한 것만이다.
final homeRoutinesProvider = Provider<List<Routine>>((ref) {
  final current = ref.watch(routineFlowProvider).routine;
  // `.value`는 재조회(invalidate) 중에도 직전 값을 준다. `asData`를 쓰면 동기화 뒤
  // 목록을 다시 읽는 동안 화면이 순간 비어 보인다.
  // **오늘 것만 본다.** 전체 목록(`myRoutinesProvider`)을 보고 있어서 어제 것도,
  // 아직 이룸이에게 보내지 않은 것도 오늘 할 일로 보였다. 이룸이 홈과 같은
  // 목록을 봐야 보호자가 믿는 것과 이룸이 화면이 같아진다.
  final fetched = ref.watch(todayRoutinesProvider).value ?? const <Routine>[];

  // 날짜를 한 번 더 본다 — 앱이 자정을 넘겨 켜져 있으면 받아 둔 값과 흐름에 남은
  // 일과가 어제 것이 된다. 다시 받아 오기 전에도 어제 일과가 남지 않게 한다.
  final now = DateTime.now();
  final currentFetched = fetched.any((r) => r.id == current?.id);

  return [
    if (current != null &&
        !currentFetched &&
        current.steps.isNotEmpty &&
        current.isTodayOn(now))
      current,
    ...fetched.where((r) => r.steps.isNotEmpty && r.isTodayOn(now)),
  ];
});

/// 일과의 진행률(0.0~1.0).
///
/// 서버에 아직 못 보낸 체크가 있는 동안(오프라인 포함)에만 기기 기록이 기준이다 —
/// 방금 체크한 카드가 바로 보여야 하고, 로컬에서 푼 카드는 빠져야 한다.
/// 다 보낸 뒤에는 서버 값이 기준이다. 기록이 남아 있다는 이유로 계속 따르면
/// 다른 휴대폰이 끝낸 카드가 이 휴대폰에는 반영되지 않는다.
double routineProgress(Routine routine, ChildRoutineState progress) {
  if (routine.steps.isEmpty) return 0;
  // 서버에 올리지 않는 로컬 일과는 보낼 곳이 없으므로 항상 기기 기록이 기준이다
  final isLocalOnly = routine.id.isEmpty || routine.id == 'local';
  final useLocal = isLocalOnly || progress.pending.contains(routine.id);
  final done = routine.steps
      .where(
        (s) => useLocal ? progress.isChecked(routine.id, s) : s.completed,
      )
      .length;
  return done / routine.steps.length;
}
