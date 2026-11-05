package com.chuseok22.elumserver.routine.core;

import com.chuseok22.elumserver.common.infrastructure.security.Sha256Hex;

/**
 * 단계 음성으로 읽을 문장: 문장 규칙, 문장 해시
 * 앱 speak 호출부와 같은 규칙 ({표시 제목}. {설명}, 표시 제목은 제목이 비면 설명)
 */
public final class RoutineStepSpeechText {

  /// 저장 열쇠에 붙이는 해시 길이 (SHA-256 hex 앞 16자)
  private static final int HASH_LENGTH = 16;

  private RoutineStepSpeechText() {
  }

  /**
   * 제목·설명 > 읽을 문장
   */
  public static String of(String title, String description) {
    String safeDescription = description == null ? "" : description.trim();
    String displayTitle = (title == null || title.isBlank()) ? safeDescription : title.trim();
    return displayTitle + ". " + safeDescription;
  }

  /**
   * 문장 > 해시 16자 (글이 바뀌면 열쇠도 바뀜)
   */
  public static String hashOf(String text) {
    return Sha256Hex.hexOf(text).substring(0, HASH_LENGTH);
  }
}
