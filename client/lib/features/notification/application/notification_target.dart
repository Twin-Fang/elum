import 'package:flutter/foundation.dart';

import '../domain/app_notification.dart';
import '../domain/notification_type.dart';

/// 알림이 가리키는 곳: 종류와 이룸이 (푸시 메시지도 같은 값으로 만들어 이동에 씀)
@immutable
class NotificationTarget {
  const NotificationTarget({
    required this.type,
    this.profileId,
    this.notificationId,
  });

  factory NotificationTarget.fromNotification(AppNotification notification) =>
      NotificationTarget(
        type: notification.type,
        profileId: notification.profileId,
      );

  /// 푸시 data 맵(문자열만) > 이동 대상 (type 이 비었거나 앱이 모르는 종류면 null)
  static NotificationTarget? fromPushData(Map<String, String> data) {
    final type = NotificationType.fromServer(data['type']);
    if (type == null) return null;
    return NotificationTarget(
      type: type,
      profileId: data['profileId'],
      notificationId: data['notificationId'],
    );
  }

  final NotificationType type;

  /// null 이면 이룸이와 무관하거나 접근할 수 없는 이룸이
  final String? profileId;

  /// 푸시로 들어온 알림의 id (목록에서 온 이동에는 없음)
  final String? notificationId;
}
