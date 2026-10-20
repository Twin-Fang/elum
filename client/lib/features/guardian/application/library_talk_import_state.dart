import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/logger/app_logger.dart';
import '../../../core/storage/local_storage.dart';

/// 이야기에서 가져온 일과 중 상세를 연 적 있는 일과 id (일과관리 칸의 `새로` 표시를 끈다)
///
/// 로컬에만 저장한다. 상세를 열 때 [markSeen] 으로 더한다.
final talkImportedSeenRoutineIdsProvider =
    NotifierProvider<TalkImportedSeenRoutineIdsNotifier, Set<String>>(
      TalkImportedSeenRoutineIdsNotifier.new,
    );

class TalkImportedSeenRoutineIdsNotifier extends Notifier<Set<String>> {
  @override
  Set<String> build() =>
      ref.read(localStorageProvider).talkImportedSeenRoutineIds.toSet();

  /// 이미 본 일과면 아무것도 하지 않는다. 저장이 실패해도 이번 실행에서는 본 것으로 둔다
  Future<void> markSeen(String routineId) async {
    if (state.contains(routineId)) return;
    state = {...state, routineId};
    try {
      await ref
          .read(localStorageProvider)
          .setTalkImportedSeenRoutineIds(state.toList());
    } catch (e, stack) {
      // 표시용 값이라 저장 실패로 화면 동작을 막지 않는다
      AppLogger.error('[talk import] seen routine ids save failed', e, stack);
    }
  }
}

/// 일과관리 격자가 스크롤해 보여 줄 일과 id (이야기에서 넣은 직후 `보러 가기`). 없으면 null
///
/// 격자가 그 칸을 찾아 스크롤하면 [clear] 로 비운다.
final libraryScrollTargetRoutineIdProvider =
    NotifierProvider<LibraryScrollTargetRoutineIdNotifier, String?>(
      LibraryScrollTargetRoutineIdNotifier.new,
    );

class LibraryScrollTargetRoutineIdNotifier extends Notifier<String?> {
  @override
  String? build() => null;

  void request(String routineId) => state = routineId;

  void clear() => state = null;
}
