/// 서버가 내려주는 에러 코드.
///
/// **서버 `ErrorCode.java`와 이름이 1:1로 맞는다.** 서버에 코드가 늘면 여기에도
/// 더한다 — 이름을 맞춰 두면 어디를 고쳐야 하는지가 바로 보인다. 섹션 주석도
/// 서버 파일 순서 그대로 옮겨 두 파일을 눈으로 대조할 수 있게 했다.
///
/// **문구는 여기에 두지 않는다.** 서버가 `errorMessage`로 함께 내려주고, 그 문구는
/// 이미 사용자용으로 쓰여 있다. 앱이 다시 쓰면 두 곳이 어긋난다 — 서버에서 문구를
/// 고쳐도 앱은 옛 문구를 보여주게 된다 (#347).
enum ServerErrorCode {
  internalServerError('INTERNAL_SERVER_ERROR'),
  invalidInputValue('INVALID_INPUT_VALUE'),
  methodNotAllowed('METHOD_NOT_ALLOWED'),

  // MEMBER
  duplicateUsername('DUPLICATE_USERNAME'),
  memberNotFound('MEMBER_NOT_FOUND'),
  memberSuspended('MEMBER_SUSPENDED'),
  // 탈퇴 계정 (#372). 관리자 화면에서만 난다 — 앱은 탈퇴한 계정으로 들어올 수 없다.
  memberWithdrawn('MEMBER_WITHDRAWN'),
  memberNotWithdrawn('MEMBER_NOT_WITHDRAWN'),

  // AUTH
  invalidCredentials('INVALID_CREDENTIALS'),
  invalidToken('INVALID_TOKEN'),
  expiredToken('EXPIRED_TOKEN'),

  // ROUTINE
  routineAiGenerationFailed('ROUTINE_AI_GENERATION_FAILED'),
  routineStepLimitExceeded('ROUTINE_STEP_LIMIT_EXCEEDED'),
  routineNotFound('ROUTINE_NOT_FOUND'),
  routineAccessDenied('ROUTINE_ACCESS_DENIED'),
  routineInvalidStatus('ROUTINE_INVALID_STATUS'),
  routineStepNotFound('ROUTINE_STEP_NOT_FOUND'),
  routineStepAlreadyCompleted('ROUTINE_STEP_ALREADY_COMPLETED'),
  routineStepOrderViolation('ROUTINE_STEP_ORDER_VIOLATION'),
  routineStepNotCompleted('ROUTINE_STEP_NOT_COMPLETED'),
  routineStepCancelOrderViolation('ROUTINE_STEP_CANCEL_ORDER_VIOLATION'),
  routineStepMinCount('ROUTINE_STEP_MIN_COUNT'),
  routineStepMaxCount('ROUTINE_STEP_MAX_COUNT'),
  routineStepImageNotFound('ROUTINE_STEP_IMAGE_NOT_FOUND'),
  routineRequestTooFrequent('ROUTINE_REQUEST_TOO_FREQUENT'),

  // PROMPT
  promptTemplateNotFound('PROMPT_TEMPLATE_NOT_FOUND'),
  promptTemplateBlank('PROMPT_TEMPLATE_BLANK'),
  promptTestLocalLlmFailed('PROMPT_TEST_LOCAL_LLM_FAILED'),
  promptTestGeminiTextFailed('PROMPT_TEST_GEMINI_TEXT_FAILED'),
  promptTestGeminiImageFailed('PROMPT_TEST_GEMINI_IMAGE_FAILED'),

  // ADMIN LOG
  logFileReadFailed('LOG_FILE_READ_FAILED'),

  // SYSTEM CONFIG
  systemConfigInvalidValue('SYSTEM_CONFIG_INVALID_VALUE'),

  // AI DLP 요청 암호화 (필터 계층 — errorCode 이름이 그대로 클라 식별자가 된다)
  dlpTimestampInvalid('DLP_TIMESTAMP_INVALID'),
  dlpNonceReplay('DLP_NONCE_REPLAY'),
  dlpSignatureInvalid('DLP_SIGNATURE_INVALID'),
  dlpDecryptFailed('DLP_DECRYPT_FAILED'),
  dlpEnvelopeInvalid('DLP_ENVELOPE_INVALID'),
  // 서버 설정 누락이라 클라이언트가 고칠 수 없다. 400으로 뭉뚱그리면 원인이 앱 탓처럼 보인다.
  dlpSecretNotConfigured('DLP_SECRET_NOT_CONFIGURED'),

  // --- 소셜 로그인 · 토큰 갱신 ---
  oauthProviderUnsupported('OAUTH_PROVIDER_UNSUPPORTED'),
  // 검증 실패 사유(서명·만료·대상 불일치)는 클라이언트에 구분해 알리지 않는다 —
  // 공격자에게 어디까지 통과했는지 알려주는 셈이 된다.
  oauthVerificationFailed('OAUTH_VERIFICATION_FAILED'),
  oauthEmailConflict('OAUTH_EMAIL_CONFLICT'),
  refreshTokenInvalid('REFRESH_TOKEN_INVALID'),
  // 이미 쓴 토큰이 다시 왔다 = 탈취 가능성. 해당 계정의 세션을 전부 끊는다.
  refreshTokenReused('REFRESH_TOKEN_REUSED'),

  // 이룸이 휴대폰 연결 (이슈 #200).
  // 없는 암호와 이미 쓴 암호는 **같은 문구**로 돌려준다 — 구분해 주면 어떤 암호가
  // 존재했는지가 새어 나가 추측에 단서가 된다.
  deviceLinkNotFound('DEVICE_LINK_NOT_FOUND'),
  deviceLinkExpired('DEVICE_LINK_EXPIRED'),
  deviceLinkTooManyAttempts('DEVICE_LINK_TOO_MANY_ATTEMPTS'),
  deviceLinkNotConnected('DEVICE_LINK_NOT_CONNECTED'),
  deviceLinkForbiddenForElumi('DEVICE_LINK_FORBIDDEN_FOR_ELUMI'),

  // 이룸이 · 함께 돌보는 보호자 (다중 보호자 1단계).
  // 연결되지 않은 이룸이와 없는 이룸이를 같은 404로 뭉치지 않는다 — 앱이 403이면 머물고, 404면 이룸이 등록으로 보낸다(E29).
  profileNotFound('PROFILE_NOT_FOUND'),
  profileAccessDenied('PROFILE_ACCESS_DENIED'),
  // 일과는 연결된 보호자가 모두 보지만 승인·수정·삭제는 만든 사람만 한다 (명세 4-2).
  routineNotCreator('ROUTINE_NOT_CREATOR'),
  // 두 사람(두 기기)이 동시에 순서를 바꿔 보낸 목록이 옛 목록이 됐다 (E24).
  routineOrderConflict('ROUTINE_ORDER_CONFLICT'),

  // 요금제 한도.
  // 문구는 해요체·능동형으로 쓰고 "아이"라는 말을 쓰지 않는다 (docs 용어 규칙).
  routineCreateLimitExceeded('ROUTINE_CREATE_LIMIT_EXCEEDED'),
  // 하루 한도 (#368). 주간과 코드를 나눈다 — 제보를 받았을 때 어느 한도인지 가려야 하고,
  // "내일 다시" 는 하루 한도에서만 맞는 말이다.
  routineCreateDailyLimitExceeded('ROUTINE_CREATE_DAILY_LIMIT_EXCEEDED'),
  routineCountLimitExceeded('ROUTINE_COUNT_LIMIT_EXCEEDED'),
  profileCountLimitExceeded('PROFILE_COUNT_LIMIT_EXCEEDED'),

  // 서비스 전체 하루 AI 비용 상한 (#368). 계정 한도와 다른 코드로 둔다 — 이 사람이 많이
  // 쓴 것이 아니라 서비스 전체가 닿은 것이라, 문구도 "다 썼어요" 가 아니다.
  aiDailyBudgetExceeded('AI_DAILY_BUDGET_EXCEEDED'),

  // 비밀값(외부 API 키) 저장.
  secretMasterKeyMissing('SECRET_MASTER_KEY_MISSING'),
  secretEncryptFailed('SECRET_ENCRYPT_FAILED'),

  // 이미지 생성 제공자.
  imageProviderUnavailable('IMAGE_PROVIDER_UNAVAILABLE'),
  imageProviderNotConfigured('IMAGE_PROVIDER_NOT_CONFIGURED'),

  // 텍스트 생성 제공자.
  textProviderUnavailable('TEXT_PROVIDER_UNAVAILABLE'),

  // 점검 모드 (이슈 #279). 점검 중에는 앱 상태 확인·약관 읽기·토큰 갱신을 뺀 API를 막는다.
  maintenanceMode('MAINTENANCE_MODE'),

  // 약관 문서 (이슈 #278).
  consentDocumentNotFound('CONSENT_DOCUMENT_NOT_FOUND'),
  consentReasonRequired('CONSENT_REASON_REQUIRED'),
  consentFieldBlank('CONSENT_FIELD_BLANK'),
  consentFieldTooLong('CONSENT_FIELD_TOO_LONG'),
  consentVersionRequired('CONSENT_VERSION_REQUIRED'),
  consentVersionInvalid('CONSENT_VERSION_INVALID'),
  consentVersionNotNewer('CONSENT_VERSION_NOT_NEWER'),

  // 앱 공지 (이슈 #370). 관리자 화면 저장 검증과 공지 조회에서 난다.
  noticeNotFound('NOTICE_NOT_FOUND'),
  noticeImageNotFound('NOTICE_IMAGE_NOT_FOUND'),
  noticeTitleBlank('NOTICE_TITLE_BLANK'),
  noticeTitleTooLong('NOTICE_TITLE_TOO_LONG'),
  noticeTitleEmphasisUnpaired('NOTICE_TITLE_EMPHASIS_UNPAIRED'),
  noticeBodyBlank('NOTICE_BODY_BLANK'),
  noticeBodyTooLong('NOTICE_BODY_TOO_LONG'),
  noticeButtonIncomplete('NOTICE_BUTTON_INCOMPLETE'),
  noticeButtonLabelTooLong('NOTICE_BUTTON_LABEL_TOO_LONG'),
  noticeButtonUrlInvalid('NOTICE_BUTTON_URL_INVALID'),
  noticePeriodInvalid('NOTICE_PERIOD_INVALID'),
  noticePriorityInvalid('NOTICE_PRIORITY_INVALID'),
  noticePlatformInvalid('NOTICE_PLATFORM_INVALID'),
  noticeImageInvalidType('NOTICE_IMAGE_INVALID_TYPE'),
  noticeImageTooLarge('NOTICE_IMAGE_TOO_LARGE'),
  noticeImageSaveFailed('NOTICE_IMAGE_SAVE_FAILED'),

  /// 앱이 모르는 코드. **서버가 새 코드를 먼저 배포하는 일은 반드시 생긴다.**
  /// 그때도 `errorMessage`는 맞으므로 문구는 그대로 보여줄 수 있다.
  unknown('');

  const ServerErrorCode(this.wire);

  /// 서버가 보내는 문자열 그대로.
  final String wire;

  /// 못 알아보는 값은 [unknown]이다 — 던지지 않는다.
  static ServerErrorCode from(String? raw) {
    if (raw == null || raw.isEmpty) return unknown;
    for (final c in values) {
      if (c.wire == raw) return c;
    }
    return unknown;
  }
}
