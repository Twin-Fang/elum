import 'package:flutter/material.dart';

import '../../../../core/l10n/date_labels.dart';
import '../../../../l10n/app_localizations.dart';
import '../../application/notification_day_grouping.dart';
import '../../domain/app_notification.dart';
import '../../domain/notification_type.dart';

/// 알림 한 줄 문구: 종류 + 제목·건수 > 한 문장 (제목을 모르면 제목 없는 문장)
String notificationHeadline(AppLocalizations l10n, AppNotification notification) {
  final title = notification.routineTitle;
  switch (notification.type) {
    case NotificationType.routineCompleted:
      if (notification.count > 1) {
        return l10n.notificationRoutineCompletedMany(notification.count);
      }
      return title == null
          ? l10n.notificationRoutineCompletedNoTitle
          : l10n.notificationRoutineCompletedOne(title);
    case NotificationType.routineSentByCoGuardian:
      return title == null
          ? l10n.notificationRoutineSentNoTitle
          : l10n.notificationRoutineSent(title);
    case NotificationType.coGuardianJoined:
      return l10n.notificationCoGuardianJoined;
    case NotificationType.creditRefilled:
      return l10n.notificationCreditRefilled;
    case NotificationType.feedbackResolved:
      return l10n.notificationFeedbackResolved;
  }
}

/// 종류 > 왼쪽 원 안 아이콘
IconData notificationIcon(NotificationType type) => switch (type) {
      NotificationType.routineCompleted => Icons.check_rounded,
      NotificationType.routineSentByCoGuardian => Icons.send_rounded,
      NotificationType.coGuardianJoined => Icons.group_add_rounded,
      NotificationType.creditRefilled => Icons.toll_rounded,
      NotificationType.feedbackResolved => Icons.chat_bubble_outline_rounded,
    };

/// 날짜 묶음 > 머리글
String notificationDayLabel(AppLocalizations l10n, NotificationDay day) =>
    switch (day) {
      NotificationDay.today => l10n.notificationDayToday,
      NotificationDay.yesterday => l10n.notificationDayYesterday,
      NotificationDay.earlier => l10n.notificationDayEarlier,
    };

/// 오늘·어제 묶음은 시각, 그 이전은 날짜
String notificationTimeLabel(
  BuildContext context,
  NotificationDay day,
  DateTime occurredAt,
) {
  final local = occurredAt.toLocal();
  if (day == NotificationDay.earlier) {
    return AppLocalizations.of(context).yearMonthDay(local);
  }
  return MaterialLocalizations.of(context).formatTimeOfDay(
    TimeOfDay.fromDateTime(local),
  );
}
