package com.chuseok22.elumserver.ai.core;

/**
 * Claude API 키 1개: 고유 id(순서를 바꿔도 상태가 따라감), 별명, 키 값, 사용 여부
 * 목록 순서가 우선순위 (0번이 1순위). 키 값은 로그·화면·호출 기록에 내보내지 않고 별명·끝 4자리만 쓴다
 */
public record ClaudeApiKey(String id, String nickname, String apiKey, boolean enabled) {

  // 화면에 보일 키 끝 자리 수
  private static final int VISIBLE_SUFFIX_LENGTH = 4;

  /// 화면용 가린 키 (예: ••••Ab3d)
  public String maskedKey() {
    if (apiKey == null || apiKey.length() <= VISIBLE_SUFFIX_LENGTH) {
      return "••••";
    }
    return "••••" + apiKey.substring(apiKey.length() - VISIBLE_SUFFIX_LENGTH);
  }

  public ClaudeApiKey withEnabled(boolean isEnabled) {
    return new ClaudeApiKey(id, nickname, apiKey, isEnabled);
  }

  public ClaudeApiKey withApiKey(String newApiKey) {
    return new ClaudeApiKey(id, nickname, newApiKey, enabled);
  }

  public ClaudeApiKey withNickname(String newNickname) {
    return new ClaudeApiKey(id, newNickname, apiKey, enabled);
  }
}
