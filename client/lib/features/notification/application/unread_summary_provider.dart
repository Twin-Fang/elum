import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/logger/app_logger.dart';
import '../../../shared/models/notice_platform.dart';
import '../data/notification_repository.dart';
import '../domain/unread_summary.dart';

/// 안 읽음 요약: 종 아이콘 빨간 점의 원본 (보호자 단위라 프로필 전환과 무관)
final unreadSummaryProvider =
    AsyncNotifierProvider<UnreadSummaryNotifier, UnreadSummary>(
  UnreadSummaryNotifier.new,
);

class UnreadSummaryNotifier extends AsyncNotifier<UnreadSummary> {
  @override
  Future<UnreadSummary> build() => _fetchOrNone();

  /// 다시 받기. 기존 값을 화면에 둔 채 바꿔서 점이 깜빡이지 않음
  Future<void> refresh() async {
    final summary = await _fetchOrNone();
    state = AsyncData(summary);
  }

  // 실패해도 팝업 없이 점만 없앰 (종 아이콘은 부가 기능)
  Future<UnreadSummary> _fetchOrNone() async {
    try {
      return await ref
          .read(notificationRepositoryProvider)
          .fetchUnreadSummary(NoticePlatform.current);
    } catch (e, st) {
      AppLogger.error('notification', e, st, {'step': 'unreadSummary'});
      return UnreadSummary.none;
    }
  }
}
