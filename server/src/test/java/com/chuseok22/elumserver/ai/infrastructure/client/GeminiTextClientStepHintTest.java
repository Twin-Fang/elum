package com.chuseok22.elumserver.ai.infrastructure.client;

import static org.assertj.core.api.Assertions.assertThat;

import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;

/**
 * 이슈 #453 — 스키마의 설명 힌트가 옛 긴 예시로 되돌아가지 않게 못박는다.
 *
 * <p>스키마 힌트는 운영 DB 프롬프트와 별개로 코드라서 배포 즉시 적용된다. 여기에 긴 예시가
 * 남아 있으면 프롬프트를 짧게 고쳐도 AI가 예시 길이에 끌려간다.
 */
class GeminiTextClientStepHintTest {

  @Test
  @DisplayName("카드 설명 힌트는 짧은 한 문장을 요청하고 옛 긴 예시를 쓰지 않는다")
  void stepDescriptionHint_asksForShortSentence() {
    assertThat(GeminiTextClient.STEP_DESCRIPTION_HINT)
      .contains("12자 안팎")
      .doesNotContain("조금 더 자세")
      .doesNotContain("학교에 입고 갈 옷을 차례대로 입어요");
  }
}
