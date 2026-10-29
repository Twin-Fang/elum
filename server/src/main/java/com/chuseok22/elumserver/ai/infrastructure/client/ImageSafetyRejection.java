package com.chuseok22.elumserver.ai.infrastructure.client;

import java.util.regex.Matcher;
import java.util.regex.Pattern;

/**
 * 그림 AI 안전 시스템 거절 판별: 예외 메시지(원인 포함)에서 거절 여부와 사유(self-harm, sexual 등) 추출
 * 같은 요청을 반복해도 결과가 같으므로 429 와 달리 장면 문장을 바꿔 한 번만 다시 시도
 */
public final class ImageSafetyRejection {

  // OpenAI: "Your request was rejected by the safety system ... safety_violations=[sexual]."
  private static final String REJECTION_MARKER = "rejected by the safety system";
  private static final Pattern REASONS = Pattern.compile("safety_violations=\\[([a-z_,\\- ]{1,60})]");
  private static final int MAX_CAUSE_DEPTH = 5;

  private ImageSafetyRejection() {
  }

  public static boolean isRejection(Throwable error) {
    return findMessage(error) != null;
  }

  /// 거절 사유 목록 (로그용, 영문 소문자 어휘만 통과). 사유가 없으면 unknown
  public static String reasonsOf(Throwable error) {
    String message = findMessage(error);
    if (message == null) {
      return "unknown";
    }
    Matcher matcher = REASONS.matcher(message);
    return matcher.find() ? matcher.group(1).trim() : "unknown";
  }

  private static String findMessage(Throwable error) {
    Throwable current = error;
    for (int depth = 0; current != null && depth < MAX_CAUSE_DEPTH; depth++) {
      String message = current.getMessage();
      if (message != null && message.contains(REJECTION_MARKER)) {
        return message;
      }
      current = current.getCause();
    }
    return null;
  }
}
