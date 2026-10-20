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

  @Test
  @DisplayName("id 가 없는 알림은 data 에서 해당 키를 뺀다 (FCM 이 null 값을 거부)")
  void data_omitsNullIds() {
    Notification notification = notification(NotificationType.CO_GUARDIAN_JOINED, "CO_GUARDIAN_JOINED:p1:m2");
    notification.setProfileId(null);
    notification.setTargetId(null);

    PushMessage message = factory.create(notification, new RecordedNotification("n1", "m1", 1, true), device(AppLocale.EN));

    assertThat(message.data()).containsOnlyKeys("type", "notificationId");
  }

  @Test
  @DisplayName("이야기 가져감 푸시는 글 제목과 가져간 보호자 수를 넣고 collapseKey 는 글 묶음 키와 같다")
  void buildBody_talkPostImported_ko() {
    Notification notification = notification(NotificationType.TALK_POST_IMPORTED, "TALK_POST_IMPORTED:post-1");

    PushMessage message = factory.create(notification, new RecordedNotification("n1", "m1", 3, true),
      device(AppLocale.KO), "버스 타기");

    assertThat(message.body()).isEqualTo("보호자 3명이 \"버스 타기\" 일과를 가져갔어요");
    assertThat(message.collapseKey()).isEqualTo("TALK_POST_IMPORTED:post-1");
  }

  @Test
  @DisplayName("이야기 댓글 푸시는 글 제목과 댓글 수를 넣고, 영어도 같은 자리에 넣는다")
  void buildBody_talkPostCommented_koAndEn() {
    Notification notification = notification(NotificationType.TALK_POST_COMMENTED, "TALK_POST_COMMENTED:post-1");
    RecordedNotification recorded = new RecordedNotification("n1", "m1", 2, true);

    assertThat(factory.create(notification, recorded, device(AppLocale.KO), "버스 타기").body())
      .isEqualTo("\"버스 타기\"에 댓글이 2개 달렸어요");
    assertThat(factory.create(notification, recorded, device(AppLocale.EN), "Bus").body())
      .isEqualTo("2 new comment(s) on \"Bus\"");
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
