import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/talk_repository.dart';
import '../domain/talk_block_entry.dart';
import 'talk_lists_invalidation.dart';

/// 내가 숨긴 보호자 목록
final talkBlocksControllerProvider =
    AsyncNotifierProvider.autoDispose<
      TalkBlocksController,
      List<TalkBlockEntry>
    >(TalkBlocksController.new);

/// 숨긴 보호자: 목록 받기, 다시 보기(차단 해제)
class TalkBlocksController extends AsyncNotifier<List<TalkBlockEntry>> {
  TalkRepository get _repository => ref.read(talkRepositoryProvider);

  @override
  Future<List<TalkBlockEntry>> build() => _repository.fetchBlocks();

  /// 차단 해제 > 목록에서 빼고 피드·인기 줄을 다시 받게 함. 실패는 [AppFailure] 로 던진다
  Future<void> unblock(String blockId) async {
    await _repository.unblock(blockId);
    if (ref.mounted) {
      final current = state.value;
      if (current != null) {
        state = AsyncData([
          for (final entry in current)
            if (entry.blockId != blockId) entry,
        ]);
      }
    }
    invalidateTalkLists(ref);
  }
}
