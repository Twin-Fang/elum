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
  });

  final List<NoticeHistoryItem> items;

  /// 서버가 준 그대로의 불투명 문자열, null 이면 마지막 쪽까지 받음
  final String? nextCursor;
  final bool isLoadingMore;
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
    if (current == null || current.isLoadingMore) return;
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
      final knownIds = {for (final item in current.items) item.id};
      state = AsyncData(
        NoticeHistoryState(
          items: [
            ...current.items,
            for (final item in page.items)
              if (!knownIds.contains(item.id)) item,
          ],
          nextCursor: page.nextCursor,
        ),
      );
    } catch (e, st) {
      AppLogger.error('notice', e, st, {'step': 'historyLoadMore'});
      if (!ref.mounted) return;
      // 실패해도 이미 받은 공지는 그대로 두고 다음 스크롤에서 다시 시도
      state = AsyncData(
        NoticeHistoryState(items: current.items, nextCursor: cursor),
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
    state = await AsyncValue.guard(build);
  }
}
