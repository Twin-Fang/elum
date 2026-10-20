import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/logger/app_logger.dart';
import '../data/talk_repository.dart';
import '../domain/talk_comment.dart';
import '../domain/talk_report_reason.dart';
import 'talk_detail_controller.dart';
import 'talk_lists_invalidation.dart';

/// 댓글 상태: 지금까지 받은 댓글(오래된 순), 다음 쪽 커서, 다음 쪽 받는 중·실패 여부
@immutable
class TalkCommentState {
  const TalkCommentState({
    required this.items,
    this.nextCursor,
    this.isLoadingMore = false,
    this.hasLoadMoreFailed = false,
  });

  final List<TalkComment> items;

  /// null 이면 마지막 쪽까지 받음
  final String? nextCursor;
  final bool isLoadingMore;

  /// 다음 쪽 받기가 실패함 (다시 시도 줄을 누르기 전까지 자동 요청 중단)
  final bool hasLoadMoreFailed;

  TalkCommentState copyWith({
    List<TalkComment>? items,
    bool? isLoadingMore,
    bool? hasLoadMoreFailed,
  }) => TalkCommentState(
    items: items ?? this.items,
    nextCursor: nextCursor,
    isLoadingMore: isLoadingMore ?? this.isLoadingMore,
    hasLoadMoreFailed: hasLoadMoreFailed ?? this.hasLoadMoreFailed,
  );
}

/// 글의 댓글 목록: 인자는 글 id
final talkCommentControllerProvider = AsyncNotifierProvider.autoDispose
    .family<TalkCommentController, TalkCommentState, String>(
      TalkCommentController.new,
    );

/// 댓글: 첫 쪽, 더 받기(커서), 달기, 지우기, 다시 받기
/// 달기·지우기 실패는 [AppFailure] 로 던지고 안내는 화면이 한다
class TalkCommentController extends AsyncNotifier<TalkCommentState> {
  TalkCommentController(this.postId);

  final String postId;

  // 서버 신고 대상 종류
  static const _reportTargetComment = 'COMMENT';

  TalkRepository get _repository => ref.read(talkRepositoryProvider);

  @override
  Future<TalkCommentState> build() async {
    final page = await _repository.fetchComments(postId);
    return TalkCommentState(items: page.items, nextCursor: page.nextCursor);
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
      final page = await _repository.fetchComments(postId, cursor: cursor);
      if (!ref.mounted) return;
      final latest = state.value ?? current;
      final knownIds = {for (final comment in latest.items) comment.id};
      state = AsyncData(
        TalkCommentState(
          items: [
            ...latest.items,
            for (final comment in page.items)
              if (!knownIds.contains(comment.id)) comment,
          ],
          nextCursor: page.nextCursor,
        ),
      );
    } catch (e, st) {
      AppLogger.error('talk', e, st, {'step': 'loadMoreComments'});
      if (!ref.mounted) return;
      state = AsyncData(
        (state.value ?? current).copyWith(
          isLoadingMore: false,
          hasLoadMoreFailed: true,
        ),
      );
    }
  }

  /// 실패한 다음 쪽 다시 받기
  Future<void> retryLoadMore() async {
    final current = state.value;
    if (current == null || !current.hasLoadMoreFailed) return;
    state = AsyncData(current.copyWith(hasLoadMoreFailed: false));
    await loadMore();
  }

  /// 처음부터 다시 받기 (차단 직후처럼 목록이 바뀐 뒤)
  Future<void> refresh() async {
    final refreshedState = await AsyncValue.guard(build);
    if (!ref.mounted) return;
    state = refreshedState;
  }

  /// 댓글 달기 > 목록 맨 뒤에 붙이고 글의 댓글 수 +1
  Future<void> add(String body) async {
    final created = await _repository.addComment(postId, body);
    if (!ref.mounted) return;
    final current = state.value;
    if (current != null && !current.items.any((it) => it.id == created.id)) {
      state = AsyncData(current.copyWith(items: [...current.items, created]));
    }
    ref
        .read(talkDetailControllerProvider(postId).notifier)
        .adjustCommentCount(1);
  }

  /// 내 댓글 지우기 > 목록에서 빼고 글의 댓글 수 -1
  Future<void> remove(String commentId) async {
    await _repository.deleteComment(commentId);
    if (!ref.mounted) return;
    final current = state.value;
    if (current != null) {
      state = AsyncData(
        current.copyWith(
          items: [
            for (final comment in current.items)
              if (comment.id != commentId) comment,
          ],
        ),
      );
    }
    ref
        .read(talkDetailControllerProvider(postId).notifier)
        .adjustCommentCount(-1);
  }

  /// 댓글 신고 (중복 신고는 서버가 TALK_REPORT_DUPLICATED 로 거절)
  Future<void> report(String commentId, TalkReportReason reason) =>
      _repository.report(
        targetType: _reportTargetComment,
        targetId: commentId,
        reason: reason.serverValue,
      );

  /// 댓글쓴이 숨기기 > 댓글 목록과 피드·인기 줄 다시 받기
  Future<void> blockAuthorOf(String commentId) async {
    await _repository.block(commentId: commentId);
    invalidateTalkLists(ref);
    await refresh();
  }
}
