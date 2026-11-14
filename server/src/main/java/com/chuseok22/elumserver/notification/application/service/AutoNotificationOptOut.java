package com.chuseok22.elumserver.notification.application.service;

import com.chuseok22.elumserver.notification.core.AutoNotificationType;
import com.chuseok22.elumserver.notification.infrastructure.entity.NotificationSetting;

/**
 * 자동 알림 종류 > 알림 설정 칸 (#1275, #1409) 단일 원본
 * 칸 4개: 일과 보내기·첫 일과 만들기 > routineNudge, 다시 찾기·이야기 인기·기기 연결 > suggestion,
 * Pro 끝나기 전 > planReminder, 첫 일과·보낸 일과 시작 전·연속 기록 > routineCompleted
 */
public final class AutoNotificationOptOut {

  /// 설정 칸 4개 (NotificationSetting 의 종류별 켜짐 칸)
  public enum OptOutGroup {
    ROUTINE_NUDGE, SUGGESTION, PLAN_REMINDER, ROUTINE_COMPLETED
  }

  private AutoNotificationOptOut() {
  }

  /// 종류 > 그 종류를 끄는 설정 칸
  public static OptOutGroup groupOf(AutoNotificationType type) {
    return switch (type) {
      case DAILY_ROUTINE_NUDGE, ONBOARDED_NO_ROUTINE -> OptOutGroup.ROUTINE_NUDGE;
      case COMEBACK, TALK_POPULAR, LINK_PENDING -> OptOutGroup.SUGGESTION;
      case PRO_GIFT_ENDING -> OptOutGroup.PLAN_REMINDER;
      case FIRST_ROUTINE_DONE, SENT_NOT_DONE, STREAK_AT_RISK -> OptOutGroup.ROUTINE_COMPLETED;
    };
  }

  /// 그 종류를 받는가 (전체 끔이면 false, 설정 행이 없으면 부르는 쪽이 켜짐으로 봄)
  public static boolean isReceiving(NotificationSetting setting, AutoNotificationType type) {
    return setting.isAllEnabled() && isTypeEnabled(setting, type);
  }

  /// 종류 칸만 (전체 끔과 무관): 알림 성과 화면 "끈 사람 수"
  public static boolean isTypeEnabled(NotificationSetting setting, AutoNotificationType type) {
    return switch (groupOf(type)) {
      case ROUTINE_NUDGE -> setting.isRoutineNudgeEnabled();
      case SUGGESTION -> setting.isSuggestionEnabled();
      case PLAN_REMINDER -> setting.isPlanReminderEnabled();
      case ROUTINE_COMPLETED -> setting.isRoutineCompletedEnabled();
    };
  }
}
