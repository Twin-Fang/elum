package com.chuseok22.elumserver.ai.infrastructure.client;

import com.chuseok22.elumserver.ai.core.AiFailureKind;
import java.util.Locale;
import java.util.Set;
import org.springframework.web.client.ResourceAccessException;
import org.springframework.web.client.RestClientResponseException;

/**
 * Claude 호출 실패 판정: 다음 키로 넘길 실패인가, 기록용 문구 (키 값은 응답 본문에 없음)
 * 다음 키: 키·권한(401·403), 결제(402), 한도(429), 과부하(529)·서버 오류(5xx), 시간 초과·연결 실패, 크레딧 부족(400 + credit balance)
 */
final class ClaudeFailures {

  // 다른 키로 바꾸면 나을 수 있는 상태 코드 (5xx 는 따로)
  private static final Set<Integer> NEXT_KEY_STATUS_CODES = Set.of(401, 402, 403, 429, 529);
  // 크레딧 소진은 400 invalid_request_error 로 옴 ("Your credit balance is too low …")
  private static final String CREDIT_BALANCE_MARKER = "credit balance";
  // 기록용 응답 본문 최대 길이
  private static final int BODY_PREVIEW_MAX_LENGTH = 300;
  private static final int SERVER_ERROR_MIN_STATUS = 500;

  private ClaudeFailures() {
  }

  static boolean shouldTryNextKey(Throwable failure) {
    if (failure instanceof ResourceAccessException) {
      return true;
    }
    if (failure instanceof RestClientResponseException responseException) {
      int status = responseException.getStatusCode().value();
      return NEXT_KEY_STATUS_CODES.contains(status) || status >= SERVER_ERROR_MIN_STATUS
        || isCreditExhausted(responseException);
    }
    return false;
  }

  /// 호출 기록·분류용 문구 (상태 코드 + 응답 본문 앞부분). AiFailureKind 가 이 문구로 원인을 나눔
  static String describe(Throwable failure) {
    if (failure instanceof RestClientResponseException responseException) {
      String responseBody = responseException.getResponseBodyAsString();
      String preview = responseBody.length() > BODY_PREVIEW_MAX_LENGTH
        ? responseBody.substring(0, BODY_PREVIEW_MAX_LENGTH) : responseBody;
      return responseException.getStatusCode().value() + " " + preview;
    }
    if (failure instanceof ResourceAccessException) {
      return "timeout or connection failed: " + failure.getMessage();
    }
    return failure.getMessage();
  }

  static AiFailureKind kindOf(Throwable failure) {
    return AiFailureKind.classify(describe(failure));
  }

  private static boolean isCreditExhausted(RestClientResponseException responseException) {
    return responseException.getResponseBodyAsString().toLowerCase(Locale.ROOT).contains(CREDIT_BALANCE_MARKER);
  }
}
