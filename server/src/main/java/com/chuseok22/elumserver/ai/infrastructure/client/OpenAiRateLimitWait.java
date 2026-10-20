package com.chuseok22.elumserver.ai.infrastructure.client;

import java.util.regex.Matcher;
import java.util.regex.Pattern;
import org.springframework.http.HttpHeaders;

/**
 * OpenAI 429 응답 > 다음 요청까지 기다릴 시간(밀리초)
 * 우선순위 3개: Retry-After 헤더(초), 본문 "try again in 3s / 350ms", 없으면 2초씩 늘려 가며(2, 4, 8초)
 */
final class OpenAiRateLimitWait {

  // 응답이 알려 준 시간 뒤에도 한도가 막 풀린 경계라 여유를 조금 더한다
  private static final long SAFETY_MARGIN_MILLISECONDS = 300;
  // 알려 준 시간이 비정상적으로 길어도 한 번에 기다리는 시간은 이 값까지
  private static final long MAX_SINGLE_WAIT_MILLISECONDS = 10_000;
  private static final long FALLBACK_BASE_WAIT_MILLISECONDS = 2_000;

  // 본문 예: "Please try again in 3s." / "try again in 350ms." / "try again in 1.5s."
  private static final Pattern TRY_AGAIN_IN_PATTERN =
    Pattern.compile("try again in ([0-9]+(?:\\.[0-9]+)?)\\s*(ms|s)", Pattern.CASE_INSENSITIVE);

  private OpenAiRateLimitWait() {
  }

  static long resolveMilliseconds(HttpHeaders responseHeaders, String responseBody, int retryIndex) {
    long announcedMilliseconds = readRetryAfterHeaderMilliseconds(responseHeaders);
    if (announcedMilliseconds <= 0) {
      announcedMilliseconds = readTryAgainInBodyMilliseconds(responseBody);
    }
    if (announcedMilliseconds <= 0) {
      return Math.min(FALLBACK_BASE_WAIT_MILLISECONDS << retryIndex, MAX_SINGLE_WAIT_MILLISECONDS);
    }
    return Math.min(announcedMilliseconds + SAFETY_MARGIN_MILLISECONDS, MAX_SINGLE_WAIT_MILLISECONDS);
  }

  private static long readRetryAfterHeaderMilliseconds(HttpHeaders responseHeaders) {
    if (responseHeaders == null) {
      return 0;
    }
    String retryAfterSeconds = responseHeaders.getFirst(HttpHeaders.RETRY_AFTER);
    if (retryAfterSeconds == null) {
      return 0;
    }
    try {
      return (long) (Double.parseDouble(retryAfterSeconds.trim()) * 1000);
    } catch (NumberFormatException ignored) {
      // 날짜 형식 Retry-After 는 쓰지 않음 > 본문·기본 대기로 넘어감
      return 0;
    }
  }

  private static long readTryAgainInBodyMilliseconds(String responseBody) {
    if (responseBody == null) {
      return 0;
    }
    Matcher matcher = TRY_AGAIN_IN_PATTERN.matcher(responseBody);
    if (!matcher.find()) {
      return 0;
    }
    double amount = Double.parseDouble(matcher.group(1));
    boolean isMilliseconds = "ms".equalsIgnoreCase(matcher.group(2));
    return (long) (isMilliseconds ? amount : amount * 1000);
  }
}
