package com.chuseok22.elumserver.common.infrastructure.exception;

import com.chuseok22.elumserver.common.locale.AppLocale;
import lombok.AllArgsConstructor;
import lombok.Getter;
import org.springframework.http.HttpStatus;

@Getter
@AllArgsConstructor
public enum ErrorCode {

  // GLOBAL
  INTERNAL_SERVER_ERROR(HttpStatus.INTERNAL_SERVER_ERROR),
  INVALID_INPUT_VALUE(HttpStatus.BAD_REQUEST),
  METHOD_NOT_ALLOWED(HttpStatus.METHOD_NOT_ALLOWED),

  // MEMBER
  DUPLICATE_USERNAME(HttpStatus.CONFLICT),
  MEMBER_NOT_FOUND(HttpStatus.NOT_FOUND),
  MEMBER_SUSPENDED(HttpStatus.FORBIDDEN),
  // 탈퇴 계정. 둘 다 관리자 화면에서만 난다 — 앱은 탈퇴한 계정으로 들어올 수 없다.
  MEMBER_WITHDRAWN(HttpStatus.CONFLICT),
  MEMBER_NOT_WITHDRAWN(HttpStatus.CONFLICT),

  // AUTH
  INVALID_CREDENTIALS(HttpStatus.UNAUTHORIZED),
  INVALID_TOKEN(HttpStatus.UNAUTHORIZED),
  EXPIRED_TOKEN(HttpStatus.UNAUTHORIZED),

  // ROUTINE
  ROUTINE_AI_GENERATION_FAILED(HttpStatus.BAD_GATEWAY),
  ROUTINE_STEP_LIMIT_EXCEEDED(HttpStatus.BAD_GATEWAY),
  ROUTINE_NOT_FOUND(HttpStatus.NOT_FOUND),
  ROUTINE_ACCESS_DENIED(HttpStatus.FORBIDDEN),
  ROUTINE_INVALID_STATUS(HttpStatus.CONFLICT),
  ROUTINE_STEP_NOT_FOUND(HttpStatus.NOT_FOUND),
  ROUTINE_STEP_ALREADY_COMPLETED(HttpStatus.CONFLICT),
  ROUTINE_STEP_ORDER_VIOLATION(HttpStatus.CONFLICT),
  ROUTINE_STEP_NOT_COMPLETED(HttpStatus.CONFLICT),
  ROUTINE_STEP_CANCEL_ORDER_VIOLATION(HttpStatus.CONFLICT),
  ROUTINE_STEP_MIN_COUNT(HttpStatus.CONFLICT),
  ROUTINE_STEP_MAX_COUNT(HttpStatus.CONFLICT),
  ROUTINE_STEP_IMAGE_NOT_FOUND(HttpStatus.NOT_FOUND),
  // 보호자가 카드 그림을 직접 찍은 사진으로 바꿀 때. 화면에 그대로 나가는 문구라 해요체다.
  ROUTINE_STEP_IMAGE_INVALID_TYPE(HttpStatus.BAD_REQUEST),
  ROUTINE_STEP_IMAGE_TOO_LARGE(HttpStatus.BAD_REQUEST),
  ROUTINE_STEP_IMAGE_SAVE_FAILED(HttpStatus.INTERNAL_SERVER_ERROR),
  ROUTINE_REQUEST_TOO_FREQUENT(HttpStatus.TOO_MANY_REQUESTS),

  // PROMPT
  PROMPT_TEMPLATE_NOT_FOUND(HttpStatus.INTERNAL_SERVER_ERROR),
  PROMPT_TEMPLATE_BLANK(HttpStatus.BAD_REQUEST),
  PROMPT_TEST_LOCAL_LLM_FAILED(HttpStatus.BAD_GATEWAY),
  PROMPT_TEST_GEMINI_TEXT_FAILED(HttpStatus.BAD_GATEWAY),
  PROMPT_TEST_GEMINI_IMAGE_FAILED(HttpStatus.BAD_GATEWAY),

  // ADMIN LOG
  LOG_FILE_READ_FAILED(HttpStatus.INTERNAL_SERVER_ERROR),
  INVALID_LOG_PATH(HttpStatus.BAD_REQUEST),
  LOG_FILE_NOT_FOUND(HttpStatus.NOT_FOUND),
  // 배포 중에는 반대 색 JVM이 아직 그 파일에 쓰고 있을 수 있다. 지우면 그 JVM의 이후 로그가 사라진다.
  LOG_FILE_IN_USE(HttpStatus.CONFLICT),
  LOG_FILE_DELETE_FAILED(HttpStatus.INTERNAL_SERVER_ERROR),
  INVALID_LOG_LEVEL(HttpStatus.BAD_REQUEST),

  // SYSTEM CONFIG
  SYSTEM_CONFIG_INVALID_VALUE(HttpStatus.BAD_REQUEST),

  // AI DLP 요청 암호화 (필터 계층 — errorCode 이름이 그대로 클라 식별자가 된다)
  DLP_TIMESTAMP_INVALID(HttpStatus.BAD_REQUEST),
  DLP_NONCE_REPLAY(HttpStatus.BAD_REQUEST),
  DLP_SIGNATURE_INVALID(HttpStatus.BAD_REQUEST),
  DLP_DECRYPT_FAILED(HttpStatus.BAD_REQUEST),
  DLP_ENVELOPE_INVALID(HttpStatus.BAD_REQUEST),
  // 서버 설정 누락이라 클라이언트가 고칠 수 없다. 400으로 뭉뚱그리면 원인이 앱 탓처럼 보인다.
  DLP_SECRET_NOT_CONFIGURED(HttpStatus.INTERNAL_SERVER_ERROR),

  // --- 소셜 로그인 · 토큰 갱신 ---
  OAUTH_PROVIDER_UNSUPPORTED(HttpStatus.BAD_REQUEST),
  // 검증 실패 사유(서명·만료·대상 불일치)는 클라이언트에 구분해 알리지 않는다 —
  // 공격자에게 어디까지 통과했는지 알려주는 셈이 된다.
  OAUTH_VERIFICATION_FAILED(HttpStatus.UNAUTHORIZED),
  OAUTH_EMAIL_CONFLICT(HttpStatus.CONFLICT),
  REFRESH_TOKEN_INVALID(HttpStatus.UNAUTHORIZED),
  // 이미 쓴 토큰이 다시 왔다 = 탈취 가능성. 해당 계정의 세션을 전부 끊는다.
  REFRESH_TOKEN_REUSED(HttpStatus.UNAUTHORIZED),

  // 이룸이 휴대폰 연결.
  // 없는 암호와 이미 쓴 암호는 **같은 문구**로 돌려준다 — 구분해 주면 어떤 암호가
  // 존재했는지가 새어 나가 추측에 단서가 된다.
  DEVICE_LINK_NOT_FOUND(HttpStatus.NOT_FOUND),
  DEVICE_LINK_EXPIRED(HttpStatus.GONE),
  DEVICE_LINK_TOO_MANY_ATTEMPTS(HttpStatus.TOO_MANY_REQUESTS),
  DEVICE_LINK_NOT_CONNECTED(HttpStatus.NOT_FOUND),
  DEVICE_LINK_FORBIDDEN_FOR_ELUMI(HttpStatus.FORBIDDEN),
  // 자기 연결 끊기(DELETE /current)는 이룸이 휴대폰 전용이다. 보호자는 linkId 로 끊는다.
  DEVICE_LINK_ONLY_FOR_ELUMI(HttpStatus.FORBIDDEN),

  // 이룸이 · 함께 돌보는 보호자 (다중 보호자 1단계).
  // 연결되지 않은 이룸이와 없는 이룸이를 같은 404로 뭉치지 않는다 — 앱이 403이면 머물고, 404면 이룸이 등록으로 보낸다(E29).
  PROFILE_NOT_FOUND(HttpStatus.NOT_FOUND),
  PROFILE_ACCESS_DENIED(HttpStatus.FORBIDDEN),
  // 일과는 연결된 보호자가 모두 보지만 승인·수정·삭제는 만든 사람만 한다 (명세 4-2).
  ROUTINE_NOT_CREATOR(HttpStatus.FORBIDDEN),
  // 두 사람(두 기기)이 동시에 순서를 바꿔 보낸 목록이 옛 목록이 됐다 (E24).
  ROUTINE_ORDER_CONFLICT(HttpStatus.CONFLICT),

  // 초대 코드. 연결 암호(DEVICE_LINK_*)와 같은 체계다 — 없는 코드와 이미 쓴 코드는
  // 같은 문구로 돌려줘 어떤 코드가 존재했는지가 새어 나가지 않게 한다.
  PROFILE_INVITE_NOT_FOUND(HttpStatus.NOT_FOUND),
  PROFILE_INVITE_EXPIRED(HttpStatus.GONE),
  // 코드 하나에 5번 틀렸거나, 한 계정이 짧은 시간에 너무 많이 시도했다.
  PROFILE_INVITE_TOO_MANY_ATTEMPTS(HttpStatus.TOO_MANY_REQUESTS),
  // 이미 이 이룸이를 함께 돌보는 사람이 코드를 넣었다 (자기가 만든 코드 포함). 코드는 쓰이지 않고 그대로 남는다.
  PROFILE_ALREADY_GUARDIAN(HttpStatus.CONFLICT),
  // 약관 동의를 마치기 전에는 이룸이 정보를 볼 근거가 없다 (E6).
  CONSENT_REQUIRED(HttpStatus.FORBIDDEN),

  // 요금제 한도.
  // 문구는 해요체·능동형으로 쓰고 "아이"라는 말을 쓰지 않는다 (docs 용어 규칙).
  ROUTINE_CREATE_LIMIT_EXCEEDED(HttpStatus.FORBIDDEN),
  // 하루 한도. 주간과 코드를 나눈다 — 제보를 받았을 때 어느 한도인지 가려야 하고,
  // "내일 다시" 는 하루 한도에서만 맞는 말이다.
  ROUTINE_CREATE_DAILY_LIMIT_EXCEEDED(HttpStatus.FORBIDDEN),
  ROUTINE_COUNT_LIMIT_EXCEEDED(HttpStatus.FORBIDDEN),
  PROFILE_COUNT_LIMIT_EXCEEDED(HttpStatus.FORBIDDEN),

  // 서비스 전체 하루 AI 비용 상한. 계정 한도와 다른 코드로 둔다 — 이 사람이 많이
  // 쓴 것이 아니라 서비스 전체가 닿은 것이라, 문구도 "다 썼어요" 가 아니다.
  AI_DAILY_BUDGET_EXCEEDED(HttpStatus.SERVICE_UNAVAILABLE),

  // 주간 AI 크레딧. 부족·진행 중·동결·장부 오류를 코드로 나눈다 — 앱이 크레딧 오류면
  // "다시 하기" 대신 "홈으로"를 보여주고, 장부 오류(UNAVAILABLE)만 다시 시도할 수 있다.
  AI_CREDIT_INSUFFICIENT(HttpStatus.FORBIDDEN),
  AI_CREDIT_JOB_IN_PROGRESS(HttpStatus.CONFLICT),
  AI_CREDIT_ACCOUNT_FROZEN(HttpStatus.FORBIDDEN),
  // 장부를 못 읽으면 막는다(fail-closed) — 열어 두면 비용이 장부 밖으로 샌다.
  AI_CREDIT_UNAVAILABLE(HttpStatus.SERVICE_UNAVAILABLE),

  // 광고 보상. 꺼짐·상한·동결은 앱이 "광고 보고 더 만들기"를 숨기거나 안내로 바꾸는 신호다.
  AD_REWARD_DISABLED(HttpStatus.FORBIDDEN),
  AD_REWARD_DAILY_LIMIT(HttpStatus.FORBIDDEN),
  AD_REWARD_ACCOUNT_FROZEN(HttpStatus.FORBIDDEN),
  AD_REWARD_SESSION_NOT_FOUND(HttpStatus.NOT_FOUND),
  // 장부를 못 읽으면 막는다(fail-closed).
  AD_REWARD_UNAVAILABLE(HttpStatus.SERVICE_UNAVAILABLE),

  // 비밀값(외부 API 키) 저장.
  SECRET_MASTER_KEY_MISSING(HttpStatus.SERVICE_UNAVAILABLE),
  SECRET_ENCRYPT_FAILED(HttpStatus.INTERNAL_SERVER_ERROR),

  // 이미지 생성 제공자.
  IMAGE_PROVIDER_UNAVAILABLE(HttpStatus.SERVICE_UNAVAILABLE),
  IMAGE_PROVIDER_NOT_CONFIGURED(HttpStatus.BAD_REQUEST),

  // 텍스트 생성 제공자.
  TEXT_PROVIDER_UNAVAILABLE(HttpStatus.SERVICE_UNAVAILABLE),

  // 점검 모드. 점검 중에는 앱 상태 확인·약관 읽기·토큰 갱신을 뺀 API를 막는다.
  MAINTENANCE_MODE(HttpStatus.SERVICE_UNAVAILABLE),

  // 약관 문서.
  CONSENT_DOCUMENT_NOT_FOUND(HttpStatus.NOT_FOUND),
  CONSENT_REASON_REQUIRED(HttpStatus.BAD_REQUEST),
  CONSENT_FIELD_BLANK(HttpStatus.BAD_REQUEST),
  CONSENT_FIELD_TOO_LONG(HttpStatus.BAD_REQUEST),
  CONSENT_VERSION_REQUIRED(HttpStatus.BAD_REQUEST),
  CONSENT_VERSION_INVALID(HttpStatus.BAD_REQUEST),
  CONSENT_VERSION_NOT_NEWER(HttpStatus.BAD_REQUEST),

  // 앱 공지. 저장 검증은 전부 400 이다 — 관리자가 고치면 되는 입력이라
  // 500 으로 두면 서버 장애와 섞인다. 관리자 화면은 E-NTC 코드를 함께 보여준다.
  NOTICE_NOT_FOUND(HttpStatus.NOT_FOUND),
  NOTICE_IMAGE_NOT_FOUND(HttpStatus.NOT_FOUND),
  NOTICE_TITLE_BLANK(HttpStatus.BAD_REQUEST),
  NOTICE_TITLE_TOO_LONG(HttpStatus.BAD_REQUEST),
  NOTICE_TITLE_EMPHASIS_UNPAIRED(HttpStatus.BAD_REQUEST),
  NOTICE_BODY_BLANK(HttpStatus.BAD_REQUEST),
  NOTICE_BODY_TOO_LONG(HttpStatus.BAD_REQUEST),
  NOTICE_BUTTON_INCOMPLETE(HttpStatus.BAD_REQUEST),
  NOTICE_BUTTON_LABEL_TOO_LONG(HttpStatus.BAD_REQUEST),
  NOTICE_BUTTON_URL_INVALID(HttpStatus.BAD_REQUEST),
  NOTICE_PERIOD_INVALID(HttpStatus.BAD_REQUEST),
  NOTICE_PRIORITY_INVALID(HttpStatus.BAD_REQUEST),
  NOTICE_PLATFORM_INVALID(HttpStatus.BAD_REQUEST),
  NOTICE_IMAGE_INVALID_TYPE(HttpStatus.BAD_REQUEST),
  NOTICE_IMAGE_TOO_LARGE(HttpStatus.BAD_REQUEST),
  NOTICE_IMAGE_SAVE_FAILED(HttpStatus.INTERNAL_SERVER_ERROR),

  // 일과 생성 가능 언어. 서버 문구 파일(폴백 질문·추천)이 비어 있는 언어는 켤 수 없다 —
  // 켜 두면 다음 기동의 시작 검사가 서버를 세우지 않는다. 관리자 화면은 E-CFG-004 를 함께 보여준다.
  CONTENT_LOCALE_NOT_READY(HttpStatus.BAD_REQUEST),

  ;


  private final HttpStatus status;

  /**
   * 한국어 문구. 관리자 화면·로그·예외 메시지처럼 요청 언어가 없는 곳에서 쓴다.
   *
   * <p>원본은 {@code i18n/messages_ko.properties} 다. 응답으로 나가는 문구는 {@link ErrorMessages} 가 요청 언어로 고른다.
   */
  public String getMessage() {
    return ErrorMessages.standard().of(this, AppLocale.KO);
  }
}
