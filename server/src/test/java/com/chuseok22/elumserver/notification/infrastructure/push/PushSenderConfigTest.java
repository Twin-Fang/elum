package com.chuseok22.elumserver.notification.infrastructure.push;

import static org.assertj.core.api.Assertions.assertThat;

import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;

/// 키가 없거나 깨졌을 때 앱이 못 뜨면 푸시 하나 때문에 서비스 전체가 멈춘다
class PushSenderConfigTest {

  private final PushSenderConfig config = new PushSenderConfig();

  @Test
  @DisplayName("키 파일이 없으면 빈 발송기가 된다")
  void missingKeyFile_yieldsNoOpSender() {
    assertThat(config.createPushSender("no-such-firebase-key.json")).isInstanceOf(NoOpPushSender.class);
    assertThat(config.createPushSender("")).isInstanceOf(NoOpPushSender.class);
    assertThat(config.createPushSender(null)).isInstanceOf(NoOpPushSender.class);
  }
}
