import 'package:flutter/foundation.dart';

import '../domain/app_notification.dart';
import '../domain/notification_type.dart';

/// 알림이 가리키는 곳: 종류와 이룸이 (푸시 메시지도 같은 값으로 만들어 이동에 씀)
@immutable
class NotificationTarget {
  const NotificationTarget({required this.type, this.profileId});

  factory NotificationTarget.fromNotification(AppNotification notification) =>
      NotificationTarget(
        type: notification.type,
        profileId: notification.profileId,
      );

  final NotificationType type;

  /// null 이면 이룸이와 무관하거나 접근할 수 없는 이룸이
  final String? profileId;
}
