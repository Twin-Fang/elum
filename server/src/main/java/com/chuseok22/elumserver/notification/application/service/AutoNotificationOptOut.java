package com.chuseok22.elumserver.notification.application.service;

import com.chuseok22.elumserver.notification.core.AutoNotificationType;
import com.chuseok22.elumserver.notification.infrastructure.entity.NotificationSetting;

/**
 * 자동 알림 종류 > 알림 설정 칸 (#1275) 단일 원본
 * 칸 4개: 오늘 일과 보내기 > routineNudge, 다시 찾기·이야기 인기 > suggestion, Pro 끝나기 전 > planReminder, 첫 일과 > routineCompleted
 */
public final class AutoNotificationOptOut {

  private AutoNotificationOptOut() {
  }

  /// 그 종류를 받는가 (전체 끔이면 false, 설정 행이 없으면 부르는 쪽이 켜짐으로 봄)
  public static boolean isReceiving(NotificationSetting setting, AutoNotificationType type) {
    return setting.isAllEnabled() && isTypeEnabled(setting, type);
  }

  /// 종류 칸만 (전체 끔과 무관): 알림 성과 화면 "끈 사람 수"
  public static boolean isTypeEnabled(NotificationSetting setting, AutoNotificationType type) {
    return switch (type) {
      case DAILY_ROUTINE_NUDGE -> setting.isRoutineNudgeEnabled();
      case COMEBACK, TALK_POPULAR -> setting.isSuggestionEnabled();
      case PRO_GIFT_ENDING -> setting.isPlanReminderEnabled();
      case FIRST_ROUTINE_DONE -> setting.isRoutineCompletedEnabled();
    };
  }
}
