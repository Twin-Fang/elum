package com.chuseok22.elumserver.routine.core;

import com.chuseok22.elumserver.common.infrastructure.exception.CustomException;
import com.chuseok22.elumserver.common.infrastructure.exception.ErrorCode;
import java.util.LinkedHashSet;
import java.util.List;
import java.util.Objects;

/**
 * 보호자 요청(칩 + 짧은 글) > 그림 지시문 한 덩어리: 칩 영어 문장들 + "Guardian note: 글"
 * 글은 60자 이하 (넘으면 400 INVALID_INPUT_VALUE), 줄바꿈·제어문자는 공백으로. 둘 다 없으면 null (그냥 다시 그림)
 */
public final class GuardianImageRequest {

  /// 요청 글 최대 길이 (앱 입력칸과 같은 값)
  public static final int MAX_REQUEST_TEXT_LENGTH = 60;

  private static final String NOTE_PREFIX = "Guardian note: ";

  private GuardianImageRequest() {
  }

  public static String compose(String requestText, List<ImageRedrawHint> hints) {
    String note = normalizeRequestText(requestText);
    StringBuilder composed = new StringBuilder();
    // 칩 (중복·null 제거, 보낸 순서 유지)
    if (hints != null) {
      new LinkedHashSet<>(hints).stream()
        .filter(Objects::nonNull)
        .forEach(hint -> composed.append(hint.getInstruction()).append(' '));
    }
    if (note != null) {
      composed.append(NOTE_PREFIX).append(note);
    }
    String result = composed.toString().trim();
    return result.isEmpty() ? null : result;
  }

  /// 요청 글 정리 (제어문자 > 공백, 앞뒤 공백 제거, 길이 검사). 비면 null
  private static String normalizeRequestText(String requestText) {
    if (requestText == null) {
      return null;
    }
    String text = requestText.replaceAll("\\p{Cntrl}", " ").replaceAll("\\s+", " ").trim();
    if (text.isEmpty()) {
      return null;
    }
    if (text.codePointCount(0, text.length()) > MAX_REQUEST_TEXT_LENGTH) {
      throw new CustomException(ErrorCode.INVALID_INPUT_VALUE);
    }
    return text;
  }
}
