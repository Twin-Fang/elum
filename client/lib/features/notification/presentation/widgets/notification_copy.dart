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
    case NotificationType.talkPostCommented:
      return l10n.notificationTalkPostCommented(notification.count);
    case NotificationType.talkPostImported:
      return l10n.notificationTalkPostImported(notification.count);
    case NotificationType.weeklyReportReady:
      return l10n.notificationWeeklyReportReady;
    case NotificationType.adminMessage:
      // 관리자가 쓴 제목 그대로 (지워졌으면 공통 문구)
      return notification.title ?? l10n.notificationAdminMessageFallback;
  }
}

/// 제목 아래 회색 설명 한 줄: 운영자 알림 본문 · 보낸 의견 앞부분 · 리포트 기간 (보여 줄 것이 없는 종류는 null)
String? notificationDetailLine(AppLocalizations l10n, AppNotification notification) {
  switch (notification.type) {
    case NotificationType.adminMessage:
      return _singleLineOf(notification.body);
    case NotificationType.feedbackResolved:
      final message = _singleLineOf(notification.body);
      return message == null ? null : l10n.notificationFeedbackQuote(message);
    case NotificationType.weeklyReportReady:
      final weekStart = DateTime.tryParse(notification.targetId ?? '');
      if (weekStart == null) return null;
      final weekEnd = DateTime(weekStart.year, weekStart.month, weekStart.day + _weekLastDayOffset);
      return l10n.notificationWeeklyReportPeriod(l10n.weekRangeOf(weekStart, weekEnd));
    case NotificationType.routineCompleted:
    case NotificationType.routineSentByCoGuardian:
    case NotificationType.coGuardianJoined:
    case NotificationType.creditRefilled:
    case NotificationType.talkPostCommented:
    case NotificationType.talkPostImported:
      return null;
  }
}

/// 주 월요일 > 일요일 (날짜 칸 더하기, 서머타임 무관)
const _weekLastDayOffset = 6;

/// 줄바꿈·연속 공백 > 공백 하나 (한 줄 칸에 쓰는 글, 비었으면 null)
String? _singleLineOf(String? text) {
  final collapsed = text?.replaceAll(RegExp(r'\s+'), ' ').trim();
  return collapsed == null || collapsed.isEmpty ? null : collapsed;
}

/// 날짜 묶음 > 머리글
String notificationDayLabel(AppLocalizations l10n, NotificationDay day) =>
    switch (day) {
      NotificationDay.today => l10n.notificationDayToday,
      NotificationDay.yesterday => l10n.notificationDayYesterday,
      NotificationDay.earlier => l10n.notificationDayEarlier,
    };

/// 오늘·어제 묶음은 시각, 그 이전은 짧은 날짜 (올해는 월·일, 다른 해는 연도 포함)
String notificationTimeLabel(
  BuildContext context,
  NotificationDay day,
  DateTime occurredAt,
) {
  final local = occurredAt.toLocal();
  if (day == NotificationDay.earlier) {
    return AppLocalizations.of(context).shortDateOf(local, DateTime.now());
  }
  return MaterialLocalizations.of(context).formatTimeOfDay(
    TimeOfDay.fromDateTime(local),
  );
}
