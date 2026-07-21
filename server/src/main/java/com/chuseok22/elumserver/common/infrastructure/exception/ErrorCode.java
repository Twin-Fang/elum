package com.chuseok22.elumserver.common.infrastructure.exception;

import lombok.AllArgsConstructor;
import lombok.Getter;
import org.springframework.http.HttpStatus;

@Getter
@AllArgsConstructor
public enum ErrorCode {

  // GLOBAL
  INTERNAL_SERVER_ERROR(HttpStatus.INTERNAL_SERVER_ERROR, "서버에 문제가 발생했습니다."),
  INVALID_INPUT_VALUE(HttpStatus.BAD_REQUEST, "입력값이 올바르지 않습니다."),
  METHOD_NOT_ALLOWED(HttpStatus.METHOD_NOT_ALLOWED, "지원하지 않는 HTTP 메서드입니다."),

  // MEMBER
  DUPLICATE_USERNAME(HttpStatus.CONFLICT, "이미 사용 중인 아이디입니다."),
  MEMBER_NOT_FOUND(HttpStatus.NOT_FOUND, "존재하지 않는 회원입니다."),

  // AUTH
  INVALID_CREDENTIALS(HttpStatus.UNAUTHORIZED, "아이디 또는 비밀번호가 올바르지 않습니다."),
  INVALID_TOKEN(HttpStatus.UNAUTHORIZED, "유효하지 않은 토큰입니다."),
  EXPIRED_TOKEN(HttpStatus.UNAUTHORIZED, "만료된 토큰입니다."),

  // ROUTINE
  ROUTINE_AI_GENERATION_FAILED(HttpStatus.BAD_GATEWAY, "AI 생성 처리에 실패했습니다."),
  ROUTINE_STEP_LIMIT_EXCEEDED(HttpStatus.BAD_GATEWAY, "생성된 단계 수가 허용 범위를 초과했습니다."),
  ROUTINE_NOT_FOUND(HttpStatus.NOT_FOUND, "존재하지 않는 일과입니다."),
  ROUTINE_ACCESS_DENIED(HttpStatus.FORBIDDEN, "해당 일과에 접근할 권한이 없습니다."),
  ROUTINE_INVALID_STATUS(HttpStatus.CONFLICT, "현재 상태에서는 처리할 수 없습니다."),
  ROUTINE_STEP_NOT_FOUND(HttpStatus.NOT_FOUND, "존재하지 않는 단계입니다."),
  ROUTINE_STEP_ALREADY_COMPLETED(HttpStatus.CONFLICT, "이미 완료된 단계입니다."),
  ROUTINE_STEP_ORDER_VIOLATION(HttpStatus.CONFLICT, "이전 단계를 먼저 완료해야 합니다."),
  ROUTINE_STEP_NOT_COMPLETED(HttpStatus.CONFLICT, "완료되지 않은 단계입니다."),
  ROUTINE_STEP_CANCEL_ORDER_VIOLATION(HttpStatus.CONFLICT, "가장 최근에 완료한 단계만 취소할 수 있습니다."),
  ROUTINE_STEP_IMAGE_NOT_FOUND(HttpStatus.NOT_FOUND, "이미지를 찾을 수 없습니다."),
  ROUTINE_REQUEST_TOO_FREQUENT(HttpStatus.TOO_MANY_REQUESTS, "너무 잦은 요청입니다. 30초 후 다시 시도해주세요."),

  // PROMPT
  PROMPT_TEMPLATE_NOT_FOUND(HttpStatus.INTERNAL_SERVER_ERROR, "프롬프트 설정을 찾을 수 없습니다."),
  PROMPT_TEST_LOCAL_LLM_FAILED(HttpStatus.BAD_GATEWAY, "로컬 LLM 테스트 호출에 실패했습니다."),
  PROMPT_TEST_GEMINI_TEXT_FAILED(HttpStatus.BAD_GATEWAY, "Gemini 텍스트 테스트 호출에 실패했습니다."),
  PROMPT_TEST_GEMINI_IMAGE_FAILED(HttpStatus.BAD_GATEWAY, "Gemini 이미지 테스트 호출에 실패했습니다."),

  ;


  private final HttpStatus status;
  private final String message;
}
