package com.chuseok22.elumserver.notification.application.service;

import static org.assertj.core.api.Assertions.assertThat;

import com.chuseok22.elumserver.notification.application.service.AutoNotificationRuleService.RuleUpdate;
import com.chuseok22.elumserver.notification.core.AutoNotificationType;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;

/// 관리자가 야간 시각이나 모르는 변수를 저장하면 밤에 알림이 가거나 보호자에게 "{이름}" 같은 글자가 그대로 간다 (#1275)
class AutoNotificationRuleServiceTest {

  @Test
  @DisplayName("보내는 시각은 08:00~20:59 만 받는다 (07:30·21:00 거절)")
  void rejectionOf_sendTimeInsideQuietHours_rejected() {
    assertThat(AutoNotificationRuleService.rejectionOf(AutoNotificationType.DAILY_ROUTINE_NUDGE, update(7, 30))).isPresent();
    assertThat(AutoNotificationRuleService.rejectionOf(AutoNotificationType.DAILY_ROUTINE_NUDGE, update(21, 0))).isPresent();
    assertThat(AutoNotificationRuleService.rejectionOf(AutoNotificationType.DAILY_ROUTINE_NUDGE, update(8, 0))).isEmpty();
    assertThat(AutoNotificationRuleService.rejectionOf(AutoNotificationType.DAILY_ROUTINE_NUDGE, update(20, 59))).isEmpty();
  }

  @Test
  @DisplayName("시각 없는 종류(첫 일과 축하)는 시각을 보지 않는다")
  void rejectionOf_firstRoutineDone_ignoresSendTime() {
    assertThat(AutoNotificationRuleService.rejectionOf(AutoNotificationType.FIRST_ROUTINE_DONE, update(null, null))).isEmpty();
  }

  @Test
  @DisplayName("변수 3개 밖의 {…} 가 있으면 거절한다")
  void rejectionOf_unknownVariable_rejected() {
    RuleUpdate unknown = new RuleUpdate(true, "{아이 이름}이 끝냈어요", "본문", "home", 9, 0, 1);

    assertThat(AutoNotificationRuleService.rejectionOf(AutoNotificationType.COMEBACK, unknown))
      .hasValueSatisfying(message -> assertThat(message).contains("{아이 이름}"));
  }

  private static RuleUpdate update(Integer hour, Integer minute) {
    return new RuleUpdate(true, "🎉 {아이이름}이 첫 일과를 끝냈어요!", "{날짜} {일과}", "home", hour, minute, 1);
  }
}
