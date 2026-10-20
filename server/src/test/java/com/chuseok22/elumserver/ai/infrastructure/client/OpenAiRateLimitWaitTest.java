package com.chuseok22.elumserver.ai.infrastructure.client;

import static org.assertj.core.api.Assertions.assertThat;

import org.junit.jupiter.api.Test;
import org.springframework.http.HttpHeaders;

/// 429 대기 시간이 틀리면 한도 직후 재시도가 또 429 로 막히거나, 화면이 오래 멈춘다.
class OpenAiRateLimitWaitTest {

  private static final String BODY_3S =
    "{\"error\":{\"message\":\"Rate limit reached for gpt-image-1-mini ... Please try again in 3s.\"}}";

  @Test
  void 본문의_초_단위_안내를_읽고_여유를_더한다() {
    assertThat(OpenAiRateLimitWait.resolveMilliseconds(new HttpHeaders(), BODY_3S, 0)).isEqualTo(3_300);
  }

  @Test
  void 본문의_밀리초_단위_안내를_읽는다() {
    String body = "Please try again in 350ms.";
    assertThat(OpenAiRateLimitWait.resolveMilliseconds(new HttpHeaders(), body, 0)).isEqualTo(650);
  }

  @Test
  void Retry_After_헤더가_본문보다_우선한다() {
    HttpHeaders headers = new HttpHeaders();
    headers.set(HttpHeaders.RETRY_AFTER, "5");
    assertThat(OpenAiRateLimitWait.resolveMilliseconds(headers, BODY_3S, 0)).isEqualTo(5_300);
  }

  @Test
  void 안내가_없으면_횟수가_늘수록_길게_기다린다() {
    assertThat(OpenAiRateLimitWait.resolveMilliseconds(null, "{}", 0)).isEqualTo(2_000);
    assertThat(OpenAiRateLimitWait.resolveMilliseconds(null, "{}", 1)).isEqualTo(4_000);
    assertThat(OpenAiRateLimitWait.resolveMilliseconds(null, null, 2)).isEqualTo(8_000);
  }

  @Test
  void 안내가_아무리_길어도_한_번에_10초까지만_기다린다() {
    String body = "Please try again in 120s.";
    assertThat(OpenAiRateLimitWait.resolveMilliseconds(new HttpHeaders(), body, 0)).isEqualTo(10_000);
  }
}
