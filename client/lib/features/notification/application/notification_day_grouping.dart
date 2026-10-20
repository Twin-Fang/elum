import '../domain/app_notification.dart';

/// 알림 묶음 구분: 오늘 / 어제 / 이전
enum NotificationDay { today, yesterday, earlier }

/// 알림 > 날짜 묶음 (기기 현지 달력 날짜 기준, 입력 순서 유지, 빈 묶음 제외)
///
/// [now] 를 받아서 자정이 지나면 호출부가 새 값으로 다시 묶을 수 있음
List<(NotificationDay, List<AppNotification>)> groupByDay(
  List<AppNotification> notifications,
  DateTime now,
) {
  final today = DateTime(now.year, now.month, now.day);
  final yesterday = DateTime(now.year, now.month, now.day - 1);

  final byDay = <NotificationDay, List<AppNotification>>{
    for (final day in NotificationDay.values) day: [],
  };
  for (final notification in notifications) {
    final local = notification.occurredAt.toLocal();
    final calendarDay = DateTime(local.year, local.month, local.day);
    final day = calendarDay == today
        ? NotificationDay.today
        : calendarDay == yesterday
            ? NotificationDay.yesterday
            : NotificationDay.earlier;
    byDay[day]!.add(notification);
  }

  return [
    for (final day in NotificationDay.values)
      if (byDay[day]!.isNotEmpty) (day, byDay[day]!),
  ];
}
