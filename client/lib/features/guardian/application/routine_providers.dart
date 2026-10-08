import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/dio_provider.dart';
import '../../../core/storage/local_storage.dart';
import '../../../shared/models/routine.dart';
import '../data/routine_repository.dart';
import '../data/routine_repository_impl.dart';
import '../domain/routine_suggestion.dart';

/// 일과 저장소. 인증 인터셉터가 붙은 [dioProvider]를 쓴다 —
/// 직접 `DioClient.create()`를 부르면 토큰이 빠져 401이 그대로 터진다.
final routineRepositoryProvider = Provider<RoutineRepository>(
  (ref) => RoutineRepositoryImpl(
    dio: ref.watch(dioProvider),
    storage: ref.watch(localStorageProvider),
  ),
);

/// 이 계정의 일과 **전부**. 날짜도 상태도 가리지 않는다.
///
/// **오늘 일과 자리에 쓰지 않는다** — 보호자 홈이 이것을 보고 있어서 어제 것도,
/// 아직 이룸이에게 보내지 않은 것(`PENDING_REVIEW`)도 오늘 할 일로 보였다.
/// 오늘 목록은 [todayRoutinesProvider] 다 (#353).
///
/// 전체가 필요한 곳(임시저장 거르기 등)만 쓴다.
final myRoutinesProvider = FutureProvider<List<Routine>>((ref) {
  return ref.watch(routineRepositoryProvider).getMyRoutines();
});

/// 임시저장 — 만들다 만 일과 (이슈 #349).
///
/// 서버의 `PENDING_REVIEW` 가 곧 임시저장이다. 카드까지 만들어졌지만 보호자가
/// 아직 확인하지 않은 상태다. **`승인 대기`라 부르지 않는다** — 만들다 만 것이지
/// 심사가 아니다 (용어 규칙).
///
/// 전용 API 를 따로 두지 않고 내 일과 목록에서 걸러 쓴다. 목록이 길어지면
/// 서버에 상태 필터를 다는 편이 낫지만, 지금은 한 보호자의 일과가 많지 않다.
final draftRoutinesProvider = FutureProvider<List<Routine>>((ref) async {
  final all = await ref.watch(myRoutinesProvider.future);
  // 남이 만든 임시저장은 이어서 만들 수 없다 — 승인·수정은 만든 사람만 한다 (다중 보호자 #362).
  // 서버는 이룸이의 임시저장을 만든 사람과 상관없이 모두 준다.
  return all
      .where((r) => r.status == 'PENDING_REVIEW' && r.isEditableByMe)
      .toList();
});

/// 오늘 할 일 목록. **보호자 홈과 이룸이 홈이 같이 본다** (이슈 #75 · #353).
///
/// 서버가 `scheduledAt` 이 오늘이고 `CONFIRMED`·`COMPLETED` 인 것만 준다.
/// 승인하면 서버가 `scheduledAt` 을 그날로 옮기므로(`RoutineService.confirm` —
/// *"승인한 날이 곧 그 일과를 하는 날이다"*), **오늘 못 한 일과는 다음 날이
/// 되면 저절로 지난 일과로 넘어간다.**
///
/// 보호자 홈이 이것을 안 보고 전체 목록을 보고 있어서, 보호자가 "오늘 할 일"로
/// 믿는 것과 이룸이 화면에 뜨는 것이 서로 달랐다 (#353).
final todayRoutinesProvider = FutureProvider<List<Routine>>((ref) {
  return ref.watch(routineRepositoryProvider).getTodayRoutines();
});

/// 지난 일과 목록. 보호자_홈 아래쪽 구역이 구독한다 (이슈 #258).
///
/// 오늘 목록과 따로 받는다 — 지난 일과는 자주 바뀌지 않아 오늘 목록이 갱신될 때마다
/// 함께 부를 이유가 없다.
final pastRoutinesProvider = FutureProvider<List<Routine>>((ref) {
  return ref.watch(routineRepositoryProvider).getPastRoutines();
});

/// 추천 일과. 보호자_홈 타일과 일과 만들기 화면의 칩이 함께 구독한다.
///
/// 서버가 매 호출마다 셔플하므로 두 화면이 각자 부르면 목록이 달라진다.
/// 같은 provider를 공유해 한 번만 받아 쓴다.
final routineSuggestionsProvider = FutureProvider<List<RoutineSuggestion>>((
  ref,
) {
  return ref.watch(routineRepositoryProvider).getSuggestions();
});

/// 일과 목록을 **세 개 다** 다시 받는다.
///
/// 목록이 셋으로 나뉘어 산다 — 오늘([todayRoutinesProvider]) · 지난
/// ([pastRoutinesProvider]) · 전체([myRoutinesProvider], 임시저장이 여기서
/// 걸러 쓴다). 하나를 바꾸면 나머지도 달라질 수 있다. 일과를 지우면 오늘에서도
/// 빠지고 전체에서도 빠진다.
///
/// **한쪽만 무효화하면 화면마다 다른 것을 보게 된다.** 그 일이 실제로 있었다 —
/// 홈이 전체 목록을 보고 있어서 어제 것과 승인 전 것이 오늘 할 일에 섞였다
/// (#353). 부르는 쪽이 매번 셋을 기억하지 않도록 한 곳에 묶는다.
extension RoutineListRefresh on WidgetRef {
  void refreshRoutines() {
    invalidate(todayRoutinesProvider);
    invalidate(pastRoutinesProvider);
    invalidate(myRoutinesProvider);
  }
}

/// 화면을 떠난 뒤(위젯이 사라진 뒤)에 부를 때 쓰는 같은 것 — 컨테이너를 붙잡아 둔다.
extension RoutineListRefreshContainer on ProviderContainer {
  void refreshRoutines() {
    invalidate(todayRoutinesProvider);
    invalidate(pastRoutinesProvider);
    invalidate(myRoutinesProvider);
  }
}

/// notifier 쪽에서 쓰는 같은 것.
extension RoutineListRefreshRef on Ref {
  void refreshRoutines() {
    invalidate(todayRoutinesProvider);
    invalidate(pastRoutinesProvider);
    invalidate(myRoutinesProvider);
  }
}
