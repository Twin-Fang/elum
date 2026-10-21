package com.chuseok22.elumserver.ai.infrastructure.client;

import static org.assertj.core.api.Assertions.assertThat;

import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;

class ImageSafetyRejectionTest {

  private static final String SAFETY_MESSAGE = "400 Bad Request: \"{ \"error\": { \"message\": "
    + "\"Your request was rejected by the safety system. safety_violations=[self-harm].\" } }\"";

  @Test
  @DisplayName("안전 시스템 거절 메시지면 거절로 보고 사유를 뽑는다")
  void detectsRejectionAndReasons() {
    RuntimeException error = new RuntimeException(SAFETY_MESSAGE);

    assertThat(ImageSafetyRejection.isRejection(error)).isTrue();
    assertThat(ImageSafetyRejection.reasonsOf(error)).isEqualTo("self-harm");
  }

  @Test
  @DisplayName("원인(cause) 안에 거절 메시지가 있어도 찾는다")
  void findsRejectionInCause() {
    RuntimeException wrapped = new RuntimeException("이미지 호출 실패", new RuntimeException(SAFETY_MESSAGE));

    assertThat(ImageSafetyRejection.isRejection(wrapped)).isTrue();
  }

  @Test
  @DisplayName("429 같은 다른 오류는 거절이 아니고 사유는 unknown")
  void otherErrorsAreNotRejections() {
    RuntimeException rateLimited = new RuntimeException("429 Too Many Requests: Rate limit reached");

    assertThat(ImageSafetyRejection.isRejection(rateLimited)).isFalse();
    assertThat(ImageSafetyRejection.reasonsOf(rateLimited)).isEqualTo("unknown");
  }

  @Test
  @DisplayName("거절인데 사유 표기가 없으면 unknown")
  void rejectionWithoutReasons() {
    RuntimeException error = new RuntimeException("rejected by the safety system");

    assertThat(ImageSafetyRejection.isRejection(error)).isTrue();
    assertThat(ImageSafetyRejection.reasonsOf(error)).isEqualTo("unknown");
  }
}
