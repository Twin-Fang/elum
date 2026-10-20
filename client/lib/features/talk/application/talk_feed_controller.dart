import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/logger/app_logger.dart';
import '../data/talk_repository.dart';
import '../domain/talk_post.dart';

/// 피드 상태: 지금까지 받은 글, 다음 쪽 커서, 다음 쪽 받는 중 여부
@immutable
class TalkFeedState {
  const TalkFeedState({
    required this.items,
    this.nextCursor,
    this.isLoadingMore = false,
    this.hasLoadMoreFailed = false,
  });

  final List<TalkPostSummary> items;

  /// null 이면 마지막 쪽까지 받음
  final String? nextCursor;
  final bool isLoadingMore;

  /// 다음 쪽 받기가 실패함 (다시 시도 줄을 누르거나 새로고침하기 전까지 자동 요청 중단)
  final bool hasLoadMoreFailed;

  TalkFeedState copyWith({bool? isLoadingMore, bool? hasLoadMoreFailed}) =>
      TalkFeedState(
        items: items,
        nextCursor: nextCursor,
        isLoadingMore: isLoadingMore ?? this.isLoadingMore,
        hasLoadMoreFailed: hasLoadMoreFailed ?? this.hasLoadMoreFailed,
      );
}

/// 분류별 피드: 인자는 분류 서버 값(SELF_CARE 등), 전체는 null
final talkFeedControllerProvider = AsyncNotifierProvider.autoDispose
    .family<TalkFeedController, TalkFeedState, String?>(TalkFeedController.new);

/// 이야기 피드: 첫 쪽, 더 받기(커서), 다시 받기, 새로고침
class TalkFeedController extends AsyncNotifier<TalkFeedState> {
  TalkFeedController(this.category);

  /// 분류 서버 값. null 이면 전체
  final String? category;

  TalkRepository get _repository => ref.read(talkRepositoryProvider);

  @override
  Future<TalkFeedState> build() async {
    final page = await _repository.fetchFeed(category: category);
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
      final page = await _repository.fetchFeed(
        category: category,
        cursor: cursor,
      );
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
      AppLogger.error('talk', e, st, {'step': 'loadMore'});
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

  /// 처음부터 다시 받기 (실패 시 에러 상태)
  Future<void> refresh() async {
    final refreshedState = await AsyncValue.guard(build);
    if (!ref.mounted) return;
    state = refreshedState;
  }
}
