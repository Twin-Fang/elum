package com.chuseok22.elumserver.notification.infrastructure.push;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatCode;

import java.util.HashMap;
import java.util.Map;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;

class FcmPushSenderTest {

  @Test
  @DisplayName("data 의 null·빈 값 항목은 FCM 에 넘기기 전에 뺀다")
  void nonBlankEntries_dropsNullAndBlankValues() {
    Map<String, String> data = new HashMap<>();
    data.put("type", "CO_GUARDIAN_JOINED");
    data.put("profileId", null);
    data.put("targetId", " ");

    assertThat(FcmPushSender.nonBlankEntries(data)).containsOnlyKeys("type");
  }

  @Test
  @DisplayName("모든 알림 모양(id 전부·id 없음·긴 묶음 키)에서 FCM 메시지가 조립된다")
  void toFcmMessage_buildsForEveryNotificationShape() {
    FcmPushSender sender = new FcmPushSender(null);
    PushMessage routineCompleted = new PushMessage("token-1", "ELUM", "done",
      Map.of("type", "ROUTINE_COMPLETED", "notificationId", "n1", "profileId", "p1", "targetId", "r1"),
      "ROUTINE_COMPLETED:" + "x".repeat(72));
    PushMessage coGuardianJoined = new PushMessage("token-1", "ELUM", "joined",
      Map.of("type", "CO_GUARDIAN_JOINED", "notificationId", "n2"), "CO_GUARDIAN_JOINED:p1:m2");

    assertThatCode(() -> sender.toFcmMessage(routineCompleted)).doesNotThrowAnyException();
    assertThatCode(() -> sender.toFcmMessage(coGuardianJoined)).doesNotThrowAnyException();
  }
}
