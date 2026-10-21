import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/app_failure.dart';
import '../../../shared/models/routine.dart';
import '../data/routine_library_api.dart';
import 'routine_providers.dart';

/// 오늘 이미 보낸 원본 id: 오늘 일과 중 원본에서 보낸 것 + 오늘 만든 원본 자신
///
/// 오늘 목록을 못 받았으면 빈 집합 — 표시만 빠지고, 두 번 보내기는 서버가 막는다.
final sentTodaySourceIdsProvider = Provider<Set<String>>((ref) {
  final today = ref.watch(todayRoutinesProvider).value ?? const <Routine>[];
  return {for (final routine in today) routine.sourceRoutineId ?? routine.id};
});

final routineLibraryControllerProvider = Provider<RoutineLibraryController>(
  (ref) => RoutineLibraryController(ref),
);

/// 일과관리 동작: 보내기, 복사하기, 이름 바꾸기, 지우기 > 성공하면 목록 다시 받기
class RoutineLibraryController {
  RoutineLibraryController(this._ref);

  final Ref _ref;

  RoutineLibraryApi get _api => _ref.read(routineLibraryApiProvider);

  /// 오늘 보내기 (홈 오늘 일과·이룸이 홈이 함께 바뀐다)
  Future<Attempt<Routine>> sendToday(String routineId) =>
      _refreshAfter(_api.sendToday(routineId));

  /// 복사본은 홈에 나오지 않지만 목록은 함께 다시 받는다 (한 곳에서 묶어 받기)
  Future<Attempt<Routine>> copy(String routineId) =>
      _refreshAfter(_api.copy(routineId));

  /// 이름은 홈 목록에도 보이므로 함께 다시 받는다
  Future<Attempt<Routine>> rename(String routineId, String title) =>
      _refreshAfter(_api.rename(routineId, title));

  Future<AppFailure?> removeFromLibrary(String routineId) async {
    final failure = await _api.removeFromLibrary(routineId);
    if (failure == null) _ref.refreshRoutines();
    return failure;
  }

  /// 칸 자리 저장 (칸 사이에 놓아 옮겼을 때). 실패면 격자는 그대로
  Future<AppFailure?> saveOrder(List<({String type, String id})> cells) async {
    final failure = await _api.saveOrder(cells);
    if (failure == null) _ref.refreshRoutines();
    return failure;
  }

  /// 성공했을 때만 일과관리·오늘·지난 목록을 다시 받는다 (실패면 화면 그대로)
  Future<Attempt<Routine>> _refreshAfter(Future<Attempt<Routine>> call) async {
    final result = await call;
    if (result.isOk) _ref.refreshRoutines();
    return result;
  }
}
