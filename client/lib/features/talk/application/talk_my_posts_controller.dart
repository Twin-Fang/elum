import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/logger/app_logger.dart';
import '../data/talk_repository.dart';
import 'talk_feed_controller.dart';

/// 내가 쓴 글 목록 (내 정보 > 내가 쓴 글): 피드와 같은 상태 모양
final talkMyPostsControllerProvider =
    AsyncNotifierProvider.autoDispose<TalkMyPostsController, TalkFeedState>(
      TalkMyPostsController.new,
    );

/// 내가 쓴 글: 첫 쪽, 더 받기(커서), 다시 받기, 새로고침
class TalkMyPostsController extends AsyncNotifier<TalkFeedState> {
  TalkRepository get _repository => ref.read(talkRepositoryProvider);

  @override
  Future<TalkFeedState> build() async {
    final page = await _repository.fetchMyPosts();
    return TalkFeedState(items: page.items, nextCursor: page.nextCursor);
  }

  /// 다음 쪽 이어 붙이기 (받는 중이거나 마지막 쪽이면 무시, id 중복 제거)
  Future<void> loadMore() async {
    final current = state.value;
    if (current == null || current.isLoadingMore || current.hasLoadMoreFailed) {
      return;
    }
    final cursor = current.nextCursor;
    if (cursor == null) return;

    state = AsyncData(current.copyWith(isLoadingMore: true));
    try {
      final page = await _repository.fetchMyPosts(cursor: cursor);
      if (!ref.mounted) return;
      final latest = state.value ?? current;
      final knownIds = {for (final post in latest.items) post.id};
      state = AsyncData(
        TalkFeedState(
          items: [
            ...latest.items,
            for (final post in page.items)
              if (!knownIds.contains(post.id)) post,
          ],
          nextCursor: page.nextCursor,
        ),
      );
    } catch (e, st) {
      AppLogger.error('talk', e, st, {'step': 'loadMoreMyPosts'});
      if (!ref.mounted) return;
      // 이미 받은 글은 그대로 두고 자동 요청만 멈춘다
      state = AsyncData(
        (state.value ?? current).copyWith(
          isLoadingMore: false,
          hasLoadMoreFailed: true,
        ),
      );
    }
  }

  /// 실패한 다음 쪽 다시 받기 (다시 시도 줄)
  Future<void> retryLoadMore() async {
    final current = state.value;
    if (current == null || !current.hasLoadMoreFailed) return;
    state = AsyncData(current.copyWith(hasLoadMoreFailed: false));
    await loadMore();
  }
}
