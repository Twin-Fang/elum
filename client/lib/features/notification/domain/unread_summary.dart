import 'package:flutter/foundation.dart';

/// 안 읽음 요약: 알림 안 읽음 여부·개수, 안 읽은 공지 여부 (종 아이콘 점 표시용)
@immutable
class UnreadSummary {
  const UnreadSummary({
    required this.hasUnreadNotification,
    required this.unreadNotificationCount,
    required this.hasUnreadNotice,
  });

  final bool hasUnreadNotification;
  final int unreadNotificationCount;
  final bool hasUnreadNotice;

  /// 못 받았을 때 쓰는 값 (점 없음)
  static const none = UnreadSummary(
    hasUnreadNotification: false,
    unreadNotificationCount: 0,
    hasUnreadNotice: false,
  );

  factory UnreadSummary.fromJson(Map<String, dynamic> json) => UnreadSummary(
        hasUnreadNotification: json['hasUnreadNotification'] == true,
        unreadNotificationCount: json['unreadNotificationCount'] is num
            ? (json['unreadNotificationCount'] as num).toInt()
            : 0,
        hasUnreadNotice: json['hasUnreadNotice'] == true,
      );
}
