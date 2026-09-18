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
  MEMBER_SUSPENDED(HttpStatus.FORBIDDEN, "정지된 계정입니다. 관리자에게 문의해주세요."),

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
  ROUTINE_STEP_MIN_COUNT(HttpStatus.CONFLICT, "마지막 남은 단계는 삭제할 수 없습니다."),
  ROUTINE_STEP_MAX_COUNT(HttpStatus.CONFLICT, "카드는 10장까지 만들 수 있습니다."),
  ROUTINE_STEP_IMAGE_NOT_FOUND(HttpStatus.NOT_FOUND, "이미지를 찾을 수 없습니다."),
  ROUTINE_REQUEST_TOO_FREQUENT(HttpStatus.TOO_MANY_REQUESTS, "너무 잦은 요청입니다. 30초 후 다시 시도해주세요."),

  // PROMPT
  PROMPT_TEMPLATE_NOT_FOUND(HttpStatus.INTERNAL_SERVER_ERROR, "프롬프트 설정을 찾을 수 없습니다."),
  PROMPT_TEST_LOCAL_LLM_FAILED(HttpStatus.BAD_GATEWAY, "로컬 LLM 테스트 호출에 실패했습니다."),
  PROMPT_TEST_GEMINI_TEXT_FAILED(HttpStatus.BAD_GATEWAY, "Gemini 텍스트 테스트 호출에 실패했습니다."),
  PROMPT_TEST_GEMINI_IMAGE_FAILED(HttpStatus.BAD_GATEWAY, "Gemini 이미지 테스트 호출에 실패했습니다."),

  // ADMIN LOG
  LOG_FILE_READ_FAILED(HttpStatus.INTERNAL_SERVER_ERROR, "로그 파일을 읽는 중 오류가 발생했습니다. (E-LOG-001)"),

  // SYSTEM CONFIG
  SYSTEM_CONFIG_INVALID_VALUE(HttpStatus.BAD_REQUEST, "시스템 설정 값이 올바르지 않습니다."),

  // AI DLP 요청 암호화 (필터 계층 — errorCode 이름이 그대로 클라 식별자가 된다)
  DLP_TIMESTAMP_INVALID(HttpStatus.BAD_REQUEST, "요청 시각이 유효하지 않습니다."),
  DLP_NONCE_REPLAY(HttpStatus.BAD_REQUEST, "이미 사용된 요청입니다."),
  DLP_SIGNATURE_INVALID(HttpStatus.BAD_REQUEST, "요청 서명이 유효하지 않습니다."),
  DLP_DECRYPT_FAILED(HttpStatus.BAD_REQUEST, "요청 복호화에 실패했습니다."),
  DLP_ENVELOPE_INVALID(HttpStatus.BAD_REQUEST, "암호화 요청 형식이 올바르지 않습니다."),
  // 서버 설정 누락이라 클라이언트가 고칠 수 없다. 400으로 뭉뚱그리면 원인이 앱 탓처럼 보인다.
  DLP_SECRET_NOT_CONFIGURED(HttpStatus.INTERNAL_SERVER_ERROR, "서버에 암호화 시크릿이 설정되지 않았습니다."),

  // --- 소셜 로그인 · 토큰 갱신 ---
  OAUTH_PROVIDER_UNSUPPORTED(HttpStatus.BAD_REQUEST, "지원하지 않는 로그인 방식입니다."),
  // 검증 실패 사유(서명·만료·대상 불일치)는 클라이언트에 구분해 알리지 않는다 —
  // 공격자에게 어디까지 통과했는지 알려주는 셈이 된다.
  OAUTH_VERIFICATION_FAILED(HttpStatus.UNAUTHORIZED, "소셜 로그인 확인에 실패했습니다."),
  OAUTH_EMAIL_CONFLICT(HttpStatus.CONFLICT, "이미 다른 방법으로 가입된 이메일입니다."),
  REFRESH_TOKEN_INVALID(HttpStatus.UNAUTHORIZED, "유효하지 않은 리프레시 토큰입니다."),
  // 이미 쓴 토큰이 다시 왔다 = 탈취 가능성. 해당 계정의 세션을 전부 끊는다.
  REFRESH_TOKEN_REUSED(HttpStatus.UNAUTHORIZED, "다시 로그인해 주세요."),

  // 이룸이 휴대폰 연결 (이슈 #200).
  // 없는 암호와 이미 쓴 암호는 **같은 문구**로 돌려준다 — 구분해 주면 어떤 암호가
  // 존재했는지가 새어 나가 추측에 단서가 된다.
  DEVICE_LINK_NOT_FOUND(HttpStatus.NOT_FOUND, "암호가 맞지 않아요."),
  DEVICE_LINK_EXPIRED(HttpStatus.GONE, "암호가 만료됐어요. 새 암호를 받아주세요."),
  DEVICE_LINK_TOO_MANY_ATTEMPTS(HttpStatus.TOO_MANY_REQUESTS, "암호가 만료됐어요. 새 암호를 받아주세요."),
  DEVICE_LINK_NOT_CONNECTED(HttpStatus.NOT_FOUND, "연결된 이룸이 휴대폰이 없습니다."),
  DEVICE_LINK_FORBIDDEN_FOR_ELUMI(HttpStatus.FORBIDDEN, "이룸이 휴대폰에서는 할 수 없어요."),

  // 요금제 한도.
  // 문구는 해요체·능동형으로 쓰고 "아이"라는 말을 쓰지 않는다 (docs 용어 규칙).
  ROUTINE_CREATE_LIMIT_EXCEEDED(HttpStatus.FORBIDDEN, "이번 주에 만들 수 있는 일과를 다 썼어요."),
  ROUTINE_COUNT_LIMIT_EXCEEDED(HttpStatus.FORBIDDEN, "일과를 더 만들려면 기존 일과를 정리해주세요."),
  PROFILE_COUNT_LIMIT_EXCEEDED(HttpStatus.FORBIDDEN, "이룸이를 더 추가할 수 없어요."),

  // 비밀값(외부 API 키) 저장.
  SECRET_MASTER_KEY_MISSING(HttpStatus.SERVICE_UNAVAILABLE,
    "비밀값을 저장할 수 없습니다. 서버에 암호화 키가 설정되지 않았습니다."),
  SECRET_ENCRYPT_FAILED(HttpStatus.INTERNAL_SERVER_ERROR, "비밀값을 저장하지 못했습니다."),

  // 이미지 생성 제공자.
  IMAGE_PROVIDER_UNAVAILABLE(HttpStatus.SERVICE_UNAVAILABLE, "이미지 생성을 사용할 수 없습니다."),
  IMAGE_PROVIDER_NOT_CONFIGURED(HttpStatus.BAD_REQUEST, "해당 이미지 제공자의 설정이 없습니다."),

  ;


  private final HttpStatus status;
  private final String message;
}
