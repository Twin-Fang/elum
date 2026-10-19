package com.chuseok22.elumserver.notification.infrastructure.push;

import static org.assertj.core.api.Assertions.assertThat;

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
}
