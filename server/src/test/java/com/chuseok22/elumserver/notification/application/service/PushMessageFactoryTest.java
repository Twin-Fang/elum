package com.chuseok22.elumserver.notification.application.service;

import static org.assertj.core.api.Assertions.assertThat;

import com.chuseok22.elumserver.common.locale.AppLocale;
import com.chuseok22.elumserver.notification.core.NotificationType;
import com.chuseok22.elumserver.notification.infrastructure.entity.Notification;
import com.chuseok22.elumserver.notification.infrastructure.entity.PushDevice;
import com.chuseok22.elumserver.notification.infrastructure.push.PushMessage;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;

/// 푸시 문구에 입력 원문이 새거나 묶음 키가 어긋나면 개인정보 노출·알림창 중복이 생긴다
class PushMessageFactoryTest {

  private final PushMessageFactory factory = new PushMessageFactory();

  @Test
  @DisplayName("제목·본문·data 어디에도 일과 제목이나 이룸이 이름이 없다")
  void body_neverContainsRoutineTitleOrProfileName() {
    Notification notification = notification(NotificationType.ROUTINE_COMPLETED, "ROUTINE_COMPLETED:p1:2026-10-19");
    PushMessage message = factory.create(notification, new RecordedNotification("n1", "m1", 1, true), device(AppLocale.KO));

    String everything = message.title() + message.body() + message.data() + message.collapseKey();
    assertThat(everything).doesNotContain("세수하기").doesNotContain("하늘이");
    assertThat(message.data()).containsEntry("type", "ROUTINE_COMPLETED").containsEntry("notificationId", "n1")
      .containsEntry("profileId", "p1").containsEntry("targetId", "r1");
  }

  @Test
  @DisplayName("일과 완료 2건 이상은 개수 문구를 쓰고 collapseKey 는 묶음 키와 같다")
  void routineCompletedCount2_usesManyCopy_withCollapseKeyEqualsGroupKey() {
    Notification notification = notification(NotificationType.ROUTINE_COMPLETED, "ROUTINE_COMPLETED:p1:2026-10-19");
    PushMessage message = factory.create(notification, new RecordedNotification("n1", "m1", 2, true), device(AppLocale.KO));

    assertThat(message.title()).isEqualTo("이룸");
    assertThat(message.body()).isEqualTo("이룸이가 오늘 일과 2개를 끝냈어요");
    assertThat(message.collapseKey()).isEqualTo("ROUTINE_COMPLETED:p1:2026-10-19");
  }

  @Test
  @DisplayName("언어가 없으면 영어 문구로 대체한다")
  void unknownLocale_fallsBackToEn() {
    Notification notification = notification(NotificationType.CO_GUARDIAN_JOINED, "CO_GUARDIAN_JOINED:p1:m2");
    PushDevice device = device(null);

    PushMessage message = factory.create(notification, new RecordedNotification("n1", "m1", 1, true), device);

    assertThat(message.title()).isEqualTo("ELUM");
    assertThat(message.body()).isEqualTo("A new guardian joined");
  }

  private Notification notification(NotificationType type, String groupKey) {
    Notification notification = new Notification();
    notification.setId("n1");
    notification.setType(type);
    notification.setGroupKey(groupKey);
    notification.setProfileId("p1");
    notification.setTargetId("r1");
    return notification;
  }

  private PushDevice device(AppLocale locale) {
    PushDevice device = new PushDevice();
    device.setToken("token-1");
    device.setLocale(locale);
    return device;
  }
}
