import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/logger/app_logger.dart';
import '../../../core/storage/local_storage.dart';

/// 홈 `이야기에 공유해 보기` 링크를 닫은 원본 일과 id (닫은 일과에서는 다시 안 띄운다)
///
/// 로컬에만 저장한다. ✕ 를 누를 때 [dismiss] 로 더한다.
final talkShareHintDismissedRoutineIdsProvider =
    NotifierProvider<TalkShareHintDismissedRoutineIdsNotifier, Set<String>>(
      TalkShareHintDismissedRoutineIdsNotifier.new,
    );

class TalkShareHintDismissedRoutineIdsNotifier extends Notifier<Set<String>> {
  @override
  Set<String> build() =>
      ref.read(localStorageProvider).talkShareHintDismissedRoutineIds.toSet();

  /// 저장이 실패해도 이번 실행에서는 닫은 것으로 둔다
  Future<void> dismiss(String routineId) async {
    if (state.contains(routineId)) return;
    state = {...state, routineId};
    try {
      await ref
          .read(localStorageProvider)
          .setTalkShareHintDismissedRoutineIds(state.toList());
    } catch (e, stack) {
      // 안내용 값이라 저장 실패로 화면 동작을 막지 않는다
      AppLogger.error('[talk share hint] dismissed ids save failed', e, stack);
    }
  }
}
