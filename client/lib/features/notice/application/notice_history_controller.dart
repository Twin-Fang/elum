import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/logger/app_logger.dart';
import '../../../shared/models/notice_platform.dart';
import '../data/notice_repository.dart';
import '../domain/app_notice.dart';

/// 공지 탭 상태: 지금까지 받은 공지, 다음 쪽 커서, 다음 쪽 받는 중 여부
@immutable
class NoticeHistoryState {
  const NoticeHistoryState({
    required this.items,
    this.nextCursor,
    this.isLoadingMore = false,
    this.hasLoadMoreFailed = false,
  });

  final List<NoticeHistoryItem> items;

  /// 서버가 준 그대로의 불투명 문자열, null 이면 마지막 쪽까지 받음
  final String? nextCursor;
  final bool isLoadingMore;

  /// 다음 쪽 받기가 실패함 (새로고침 전까지 스크롤로 다시 요청하지 않음)
  final bool hasLoadMoreFailed;
}

final noticeHistoryControllerProvider = AsyncNotifierProvider.autoDispose<
    NoticeHistoryController, NoticeHistoryState>(
  NoticeHistoryController.new,
);

/// 공지 탭 목록: 첫 쪽, 더 받기, 새로고침
class NoticeHistoryController extends AsyncNotifier<NoticeHistoryState> {
  NoticeRepository get _repository => ref.read(noticeRepositoryProvider);

  @override
  Future<NoticeHistoryState> build() async {
    final page = await _repository.fetchHistory(NoticePlatform.current);
    return NoticeHistoryState(items: page.items, nextCursor: page.nextCursor);
  }

  /// 다음 쪽 이어 붙이기 (받는 중이거나 마지막 쪽이면 무시, id 중복 제거)
  Future<void> loadMore() async {
    final current = state.value;
    if (current == null || current.isLoadingMore || current.hasLoadMoreFailed) return;
    final cursor = current.nextCursor;
    if (cursor == null) return;

    state = AsyncData(
      NoticeHistoryState(
        items: current.items,
        nextCursor: cursor,
        isLoadingMore: true,
      ),
    );
    try {
      final page = await _repository.fetchHistory(
        NoticePlatform.current,
        cursor: cursor,
      );
      if (!ref.mounted) return;
      // 기다리는 동안 바뀐 상태를 잃지 않도록 지금 상태에 이어 붙임
      final latest = state.value ?? current;
      final knownIds = {for (final item in latest.items) item.id};
      state = AsyncData(
        NoticeHistoryState(
          items: [
            ...latest.items,
            for (final item in page.items)
              if (!knownIds.contains(item.id)) item,
          ],
          nextCursor: page.nextCursor,
        ),
      );
    } catch (e, st) {
      AppLogger.error('notice', e, st, {'step': 'historyLoadMore'});
      if (!ref.mounted) return;
      // 실패해도 이미 받은 공지는 그대로 두고 새로고침 전까지 자동 요청 중단
      state = AsyncData(
        NoticeHistoryState(
          items: (state.value ?? current).items,
          nextCursor: cursor,
          hasLoadMoreFailed: true,
        ),
      );
    }
  }

  /// 공지 탭을 열었다고 서버에 기록. 실패해도 목록은 그대로 보여 주므로 로그만 남기고 false
  Future<bool> markSeen() async {
    try {
      await _repository.markSeen();
      return true;
    } catch (e, st) {
      AppLogger.error('notice', e, st, {'step': 'markSeen'});
      return false;
    }
  }

  /// 처음부터 다시 받기 (실패 시 에러 상태)
  Future<void> refresh() async {
    final result = await AsyncValue.guard(build);
    if (!ref.mounted) return;
    state = result;
  }
}
