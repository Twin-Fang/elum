import 'notification_target.dart';

/// 눌렀지만 아직 열지 못한 이동 (target null 이면 알림 목록 화면)
class PendingPushOpen {
  const PendingPushOpen({
    required this.target,
    required this.notificationId,
    required this.tappedAt,
  });

  final NotificationTarget? target;
  final String? notificationId;
  final DateTime tappedAt;
}
