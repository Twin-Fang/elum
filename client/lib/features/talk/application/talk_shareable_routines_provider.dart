import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/logger/app_logger.dart';
import '../../../shared/models/routine.dart';
import '../../guardian/application/routine_providers.dart';
import 'talk_my_shared_posts_provider.dart';

/// 올릴 수 있는 일과: 일과관리 원본 중 예시·이야기에서 가져온 일과·이미 올린 일과 제외
/// 숨긴 원본·임시저장은 서버가 일과관리 목록에서 이미 뺀다
final talkShareableRoutinesProvider = FutureProvider.autoDispose<List<Routine>>(
  (ref) async {
    final libraryRoutines = await ref.watch(routineLibraryProvider.future);
    final sharedPostIdByRoutineId = await _fetchSharedPostIdByRoutineIdOrEmpty(
      ref,
    );
    return [
      for (final routine in libraryRoutines)
        if (!routine.isExample &&
            routine.talkPostId == null &&
            !sharedPostIdByRoutineId.containsKey(routine.id))
          routine,
    ];
  },
);

/// 올린 글 조회 실패 시 거르지 않는다 (이미 올린 일과는 서버가 TALK_ALREADY_SHARED 로 막는다)
Future<Map<String, String>> _fetchSharedPostIdByRoutineIdOrEmpty(
  Ref ref,
) async {
  try {
    return await ref.watch(talkMySharedPostsProvider.future);
  } catch (e) {
    AppLogger.error('talk', e, null, {'step': 'fetchMySharedPosts'});
    return const {};
  }
}

/// 올리려는 일과 원본 (일과관리 목록에 아직 없으면 null): 카드 그림·번들 그림을 찾는 데 쓴다
final talkShareSourceRoutineProvider = Provider.autoDispose
    .family<Routine?, String>((ref, routineId) {
      final libraryRoutines =
          ref.watch(routineLibraryProvider).value ?? const <Routine>[];
      for (final routine in libraryRoutines) {
        if (routine.id == routineId) return routine;
      }
      return null;
    });

/// 올리기 진입: 다른 기기에서 만들거나 올린 일과까지 반영되게 일과관리 목록 · 내가 올린 글을 다시 받는다
void refreshShareableRoutineSources(WidgetRef ref) => ref
  ..invalidate(routineLibraryProvider)
  ..invalidate(talkMySharedPostsProvider);
