package com.chuseok22.elumserver.admin.core;

import lombok.AllArgsConstructor;
import lombok.Getter;

/**
 * 관리자 기록 대상 종류 4개: 회원, 프롬프트, 의견, 로그 파일
 * 대상 id 형식: 회원·의견 id(UUID), 프롬프트 "{PromptKey}:{언어 코드}", 로그 파일 경로
 */
@Getter
@AllArgsConstructor
public enum AdminAuditTargetType {

  MEMBER("회원"),
  PROMPT("프롬프트"),
  FEEDBACK("의견"),
  LOG_FILE("로그 파일"),
  ;

  /// 프롬프트 대상 id 의 키·언어 구분자: ROUTINE_CREATE:ko
  public static final String PROMPT_TARGET_ID_DELIMITER = ":";

  private final String label;

  /// 프롬프트 키 + 언어 코드 > 대상 id (이력 화면 링크가 다시 나눠 씀)
  public static String toPromptTargetId(String promptKey, String localeCode) {
    return promptKey + PROMPT_TARGET_ID_DELIMITER + localeCode;
  }
}
