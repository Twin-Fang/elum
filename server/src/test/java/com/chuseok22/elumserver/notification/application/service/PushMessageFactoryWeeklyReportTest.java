package com.chuseok22.elumserver.notification.application.service;

import static org.assertj.core.api.Assertions.assertThat;

import com.chuseok22.elumserver.common.locale.AppLocale;
import com.chuseok22.elumserver.notification.core.NotificationType;
import com.chuseok22.elumserver.notification.infrastructure.entity.Notification;
import com.chuseok22.elumserver.notification.infrastructure.entity.PushDevice;
import com.chuseok22.elumserver.notification.infrastructure.push.PushMessage;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;

/// 주간 리포트 푸시: 앱이 리포트 화면을 못 열거나 잠금 화면에 이름·제목이 새는 것을 막는다
class PushMessageFactoryWeeklyReportTest {

  private final PushMessageFactory factory = new PushMessageFactory();

  @Test
  @DisplayName("제목은 '한 주 리포트가 왔어요', 본문은 횟수만, data 에 profileId·weekStart 가 있다")
  void weeklyReport_titleBodyAndData() {
    Notification notification = new Notification();
    notification.setId("n1");
    notification.setType(NotificationType.WEEKLY_REPORT_READY);
    notification.setProfileId("p1");
    notification.setTargetId("2026-11-02");
    notification.setGroupKey("WEEKLY_REPORT_READY:p1:2026-11-02");
    PushDevice device = new PushDevice();
    device.setToken("token");
    device.setLocale(AppLocale.KO);

    PushMessage message = factory.create(notification, new RecordedNotification("n1", "m1", 1, true), device, "4,2");

    assertThat(message.title()).isEqualTo("한 주 리포트가 왔어요");
    assertThat(message.body()).isEqualTo("이룸이가 지난주 일과 4개 중 2개를 마쳤어요");
    assertThat(message.data()).containsEntry("type", "WEEKLY_REPORT_READY").containsEntry("profileId", "p1")
      .containsEntry("weekStart", "2026-11-02").containsEntry("targetId", "2026-11-02");
    assertThat(message.collapseKey()).isEqualTo("WEEKLY_REPORT_READY:p1:2026-11-02");
  }
}
