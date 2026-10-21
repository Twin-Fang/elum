import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/logger/app_logger.dart';
import '../data/notification_repository.dart';
import '../domain/app_notification.dart';
import 'unread_summary_provider.dart';

/// 알림 목록 상태: 지금까지 받은 줄, 다음 쪽 커서, 다음 쪽 받는 중 여부
@immutable
class NotificationListState {
  const NotificationListState({
    required this.items,
    this.nextCursor,
    this.isLoadingMore = false,
    this.hasLoadMoreFailed = false,
  });

  final List<AppNotification> items;

  /// null 이면 마지막 쪽까지 받음
  final String? nextCursor;
  final bool isLoadingMore;

  /// 다음 쪽 받기가 실패함 (새로고침 전까지 스크롤로 다시 요청하지 않음)
  final bool hasLoadMoreFailed;

  bool get hasUnread => items.any((notification) => !notification.isRead);

  NotificationListState copyWith({
    List<AppNotification>? items,
    String? nextCursor,
    bool? isLoadingMore,
    bool? hasLoadMoreFailed,
  }) =>
      NotificationListState(
        items: items ?? this.items,
        nextCursor: nextCursor ?? this.nextCursor,
        isLoadingMore: isLoadingMore ?? this.isLoadingMore,
        hasLoadMoreFailed: hasLoadMoreFailed ?? this.hasLoadMoreFailed,
      );
}

final notificationListControllerProvider = AsyncNotifierProvider.autoDispose<
    NotificationListController, NotificationListState>(
  NotificationListController.new,
);

/// 알림 목록: 첫 쪽, 더 받기, 새로고침, 읽음 처리(한 줄·전체)
class NotificationListController extends AsyncNotifier<NotificationListState> {
  NotificationRepository get _repository =>
      ref.read(notificationRepositoryProvider);

  @override
  Future<NotificationListState> build() async {
    final page = await _repository.fetchPage();
    return NotificationListState(items: page.items, nextCursor: page.nextCursor);
  }

  /// 다음 쪽 이어 붙이기 (받는 중이거나 마지막 쪽이면 무시, id 중복 제거)
  Future<void> loadMore() async {
    final current = state.value;
    if (current == null || current.isLoadingMore || current.hasLoadMoreFailed) return;
    final cursor = current.nextCursor;
    if (cursor == null) return;

    state = AsyncData(current.copyWith(isLoadingMore: true));
    try {
      final page = await _repository.fetchPage(cursor: cursor);
      if (!ref.mounted) return;
      // 기다리는 동안 바뀐 읽음 상태를 잃지 않도록 지금 상태에 이어 붙임
      final latest = state.value ?? current;
      final knownIds = {for (final notification in latest.items) notification.id};
      state = AsyncData(
        NotificationListState(
          items: [
            ...latest.items,
            for (final notification in page.items)
              if (!knownIds.contains(notification.id)) notification,
          ],
          nextCursor: page.nextCursor,
        ),
      );
    } catch (e, st) {
      AppLogger.error('notification', e, st, {'step': 'loadMore'});
      if (!ref.mounted) return;
      // 실패해도 이미 받은 줄은 그대로 두고 새로고침 전까지 자동 요청 중단
      state = AsyncData(
        (state.value ?? current).copyWith(
          isLoadingMore: false,
          hasLoadMoreFailed: true,
        ),
      );
    }
  }

  /// 처음부터 다시 받기 (실패 시 에러 상태)
  Future<void> refresh() async {
    final refreshedState = await AsyncValue.guard(build);
    if (!ref.mounted) return;
    state = refreshedState;
  }

  /// 한 줄 읽음: 화면 먼저 > 서버 요청 (실패해도 되돌리지 않음) > 종 아이콘 점 갱신
  Future<void> markRead(String id) async {
    final current = state.value;
    if (current == null) return;
    final target = current.items.where((notification) => notification.id == id).firstOrNull;
    if (target == null || target.isRead) return;

    state = AsyncData(
      current.copyWith(
        items: [
          for (final notification in current.items)
            if (notification.id == id) notification.copyWith(isRead: true) else notification,
        ],
      ),
    );
    await _syncToServer('markRead', () => _repository.markRead(id));
  }

  /// 전체 읽음: 화면 먼저 > 서버 요청 (실패해도 되돌리지 않음) > 종 아이콘 점 갱신
  Future<void> markAllRead() async {
    final current = state.value;
    if (current == null || !current.hasUnread) return;

    state = AsyncData(
      current.copyWith(
        items: [for (final notification in current.items) notification.copyWith(isRead: true)],
      ),
    );
    await _syncToServer('markAllRead', _repository.markAllRead);
  }

  // 읽음 요청 공통 (성공·실패 공통으로 안 읽음 요약 갱신)
  Future<void> _syncToServer(String step, Future<void> Function() request) async {
    // 화면을 떠나 이 컨트롤러가 정리돼도 요약(전역)은 갱신해야 해서 미리 잡아 둠
    final summary = ref.read(unreadSummaryProvider.notifier);
    try {
      await request();
    } catch (e, st) {
      AppLogger.error('notification', e, st, {'step': step});
    }
    await summary.refresh();
  }
}
