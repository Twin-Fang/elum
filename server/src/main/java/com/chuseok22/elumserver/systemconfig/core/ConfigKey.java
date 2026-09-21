package com.chuseok22.elumserver.systemconfig.core;

import java.util.List;
import lombok.Getter;

// 동적으로 수정 가능한 시스템 설정의 전체 목록. 새 설정이 필요하면 여기에 키를 추가하면
// SystemConfigInitializer가 기본값을 시딩하고 관리자 화면에 자동으로 노출된다.
// 모델명 3종의 defaultValue는 코드 기본값이며, 배포 환경(yml)에 값이 있으면
// SystemConfigService.defaultValueFor()가 그 값을 우선한다.
@Getter
public enum ConfigKey {

  GEMINI_TEXT_MODEL(
    ConfigGroup.GEMINI_TEXT, "텍스트 모델",
    "루틴 생성과 추가 질문 생성에 사용하는 Gemini 모델명",
    ConfigValueType.STRING, List.of(), "gemini-2.5-flash"
  ),
  GEMINI_TEXT_TEMPERATURE(
    ConfigGroup.GEMINI_TEXT, "temperature",
    "텍스트 생성 무작위성 (0=결정적, 최대 2)",
    ConfigValueType.DECIMAL, List.of(), "0"
  ),
  GEMINI_IMAGE_MODEL(
    ConfigGroup.GEMINI_IMAGE, "이미지 모델",
    "루틴 단계 삽화 생성에 사용하는 Gemini 이미지 모델명",
    ConfigValueType.STRING, List.of(), "gemini-2.5-flash-image"
  ),
  GEMINI_IMAGE_ASPECT_RATIO(
    ConfigGroup.GEMINI_IMAGE, "이미지 비율",
    "생성 이미지의 가로세로 비율 (클라이언트 카드 영역은 4:3에 가장 가깝다)",
    ConfigValueType.SELECT, List.of("1:1", "4:3", "3:4", "16:9", "9:16"), "4:3"
  ),
  LOCAL_LLM_MODEL(
    ConfigGroup.LOCAL_LLM, "로컬 LLM 모델",
    "민감정보 검사(DLP)에 사용하는 내부 Ollama 모델명",
    ConfigValueType.STRING, List.of(), ""
  ),
  PRICE_GEMINI_TEXT_INPUT_PER_1M(
    ConfigGroup.PRICING, "텍스트 입력 단가 (USD/1M 토큰)",
    "Gemini 텍스트 입력 토큰 100만 개당 요금. AI 호출 비용 추정에 사용",
    ConfigValueType.DECIMAL, List.of(), "0.30"
  ),
  PRICE_GEMINI_TEXT_OUTPUT_PER_1M(
    ConfigGroup.PRICING, "텍스트 출력 단가 (USD/1M 토큰)",
    "Gemini 텍스트 출력 토큰 100만 개당 요금. AI 호출 비용 추정에 사용",
    ConfigValueType.DECIMAL, List.of(), "2.50"
  ),
  PRICE_GEMINI_IMAGE_PER_IMAGE(
    ConfigGroup.PRICING, "이미지 생성 단가 (USD/장)",
    "Gemini 이미지 1장 생성 요금. AI 호출 비용 추정에 사용",
    ConfigValueType.DECIMAL, List.of(), "0.039"
  ),

  // --- 이미지 생성 제공자 ---
  //
  // 카드 삽화가 AI 비용의 99%다. 제공자를 바꿀 수 있어야 원가를 줄일 수 있고,
  // 그러려면 모델명뿐 아니라 API 키도 화면에서 넣을 수 있어야 한다. 키는 암호화해
  // 저장한다(SECRET).

  IMAGE_PROVIDER_SELECTED(
    ConfigGroup.IMAGE_PROVIDER, "사용할 제공자",
    "카드 삽화를 생성할 제공자. 키가 없는 제공자는 고를 수 없다",
    ConfigValueType.SELECT, List.of("GEMINI", "OPENAI", "FLUX"), "GEMINI"
  ),
  OPENAI_API_KEY(
    ConfigGroup.IMAGE_PROVIDER, "OpenAI API 키",
    "암호화해 저장한다. 저장 후에는 다시 볼 수 없고 새 값으로 덮어쓰기만 된다",
    ConfigValueType.SECRET, List.of(), ""
  ),
  OPENAI_IMAGE_MODEL(
    ConfigGroup.IMAGE_PROVIDER, "OpenAI 이미지 모델",
    "예: gpt-image-1-mini",
    ConfigValueType.STRING, List.of(), "gpt-image-1-mini"
  ),
  OPENAI_IMAGE_QUALITY(
    ConfigGroup.IMAGE_PROVIDER, "OpenAI 이미지 품질",
    "낮출수록 싸다",
    ConfigValueType.SELECT, List.of("low", "medium", "high"), "low"
  ),
  FLUX_API_KEY(
    ConfigGroup.IMAGE_PROVIDER, "FLUX(fal.ai) API 키",
    "암호화해 저장한다. 저장 후에는 다시 볼 수 없고 새 값으로 덮어쓰기만 된다",
    ConfigValueType.SECRET, List.of(), ""
  ),
  FLUX_IMAGE_MODEL(
    ConfigGroup.IMAGE_PROVIDER, "FLUX 모델",
    "fal.ai 모델 경로. 예: fal-ai/flux/schnell",
    ConfigValueType.STRING, List.of(), "fal-ai/flux/schnell"
  ),
  // --- 텍스트 생성 제공자 ---
  //
  // 이미지와 같은 이유로 제공자를 화면에서 고른다. 다만 무게가 다르다 — OpenAI가
  // 텍스트 모델에만 무료 토큰을 주는데 영구 보장이 아니라, 끊기는 날 즉시 되돌릴
  // 수단이 필요하다. API 키는 이미지와 같은 OPENAI_API_KEY를 함께 쓴다.
  TEXT_PROVIDER_SELECTED(
    ConfigGroup.TEXT_PROVIDER, "사용할 제공자",
    "일과·추가 질문 텍스트를 생성할 제공자. 키가 없는 제공자는 고를 수 없다",
    ConfigValueType.SELECT, List.of("GEMINI", "OPENAI"), "GEMINI"
  ),
  OPENAI_TEXT_MODEL(
    ConfigGroup.TEXT_PROVIDER, "OpenAI 텍스트 모델",
    "예: gpt-4.1-mini. nano급은 한국어 문장이 깨져 권장하지 않는다",
    ConfigValueType.STRING, List.of(), "gpt-4.1-mini"
  ),
  PRICE_OPENAI_IMAGE_PER_IMAGE(
    ConfigGroup.PRICING, "OpenAI 이미지 단가 (USD/장)",
    "OpenAI 이미지 1장 생성 요금. 비용 추정에 사용",
    ConfigValueType.DECIMAL, List.of(), "0.005"
  ),
  // 아래 두 값은 OpenAI 공식 단가표를 확인하지 못해 추정치로 둔다.
  // Usage 화면의 실제 청구액과 대조해 보정한다.
  PRICE_OPENAI_TEXT_INPUT_PER_1M(
    ConfigGroup.PRICING, "OpenAI 텍스트 입력 단가 (USD/1M 토큰)",
    "OpenAI 텍스트 입력 토큰 100만 개당 요금. 비용 추정에 사용",
    ConfigValueType.DECIMAL, List.of(), "0.40"
  ),
  PRICE_OPENAI_TEXT_OUTPUT_PER_1M(
    ConfigGroup.PRICING, "OpenAI 텍스트 출력 단가 (USD/1M 토큰)",
    "OpenAI 텍스트 출력 토큰 100만 개당 요금. 비용 추정에 사용",
    ConfigValueType.DECIMAL, List.of(), "1.60"
  ),
  // 이미지도 토큰으로 과금된다. 장당 고정값만 두면 품질을 바꿔 출력 토큰이
  // 네 배가 되어도(low 272 → medium 1056) 기록된 비용은 그대로라 실제와 멀어진다.
  // 아래 두 값이 0이면 장당 고정값(PRICE_OPENAI_IMAGE_PER_IMAGE)으로 되돌아간다.
  //
  // 기본값은 실측 역산이다 — low 품질 1장이 출력 272토큰이고 장당 $0.005이므로
  // 100만 토큰당 약 $18.4. 공식 단가표를 확인하면 그 값으로 바꾼다.
  PRICE_OPENAI_IMAGE_INPUT_PER_1M(
    ConfigGroup.PRICING, "OpenAI 이미지 입력 단가 (USD/1M 토큰)",
    "프롬프트 텍스트 토큰 요금. 0이면 장당 고정 단가를 쓴다",
    ConfigValueType.DECIMAL, List.of(), "0"
  ),
  PRICE_OPENAI_IMAGE_OUTPUT_PER_1M(
    ConfigGroup.PRICING, "OpenAI 이미지 출력 단가 (USD/1M 토큰)",
    "생성 이미지 토큰 요금. 0이면 장당 고정 단가를 쓴다",
    ConfigValueType.DECIMAL, List.of(), "0"
  ),
  PRICE_FLUX_IMAGE_PER_IMAGE(
    ConfigGroup.PRICING, "FLUX 이미지 단가 (USD/장)",
    "FLUX 이미지 1장 생성 요금. 비용 추정에 사용",
    ConfigValueType.DECIMAL, List.of(), "0.006"
  ),

  // --- 플랜 한도 ---
  //
  // 무엇이 Free고 무엇이 Pro인지를 코드가 아니라 여기에 둔다. 가격 정책이 정해졌을 때
  // 배포 없이 관리자 화면에서 숫자만 바꾸기 위해서다.
  //
  // 수치 한도의 초기값은 전부 -1(무제한)이다. 구조만 넣고 지금 동작을 지금과 똑같게
  // 유지한다 — 실측 원가가 나오기 전에 숫자를 박으면 두 번 일한다.

  // ⚠️ 기본값이 아직 true다. 끄면 Free 카드에 그림이 사라지는데, 대체할 픽토그램이
  // 아직 없기 때문이다. 픽토그램이 붙으면 false로 내린다.
  FREE_AI_IMAGE_GENERATION(
    ConfigGroup.PLAN_FREE, "AI 맞춤 삽화",
    "Free에서 AI가 그린 맞춤 삽화를 쓸 수 있는지. 끄면 픽토그램을 쓴다 (픽토그램 적용 전까지는 켜 둔다)",
    ConfigValueType.BOOLEAN, List.of(), "true"
  ),
  FREE_ADS_REMOVED(
    ConfigGroup.PLAN_FREE, "광고 제거",
    "Free에서 광고를 숨길지. 꺼두면 광고가 보인다",
    ConfigValueType.BOOLEAN, List.of(), "false"
  ),
  FREE_ROUTINE_CREATE_PER_WEEK(
    ConfigGroup.PLAN_FREE, "주당 일과 생성 횟수",
    "Free가 한 주(월요일 시작)에 만들 수 있는 일과 수. -1이면 무제한",
    ConfigValueType.INTEGER, List.of(), "-1"
  ),
  FREE_ROUTINE_MAX_COUNT(
    ConfigGroup.PLAN_FREE, "보유 일과 개수",
    "Free가 동시에 가질 수 있는 일과 수. -1이면 무제한",
    ConfigValueType.INTEGER, List.of(), "-1"
  ),
  FREE_PROFILE_MAX_COUNT(
    ConfigGroup.PLAN_FREE, "이룸이 명수",
    "Free 계정 하나에 둘 수 있는 이룸이 수. -1이면 무제한",
    ConfigValueType.INTEGER, List.of(), "-1"
  ),
  FREE_HISTORY_RETENTION_DAYS(
    ConfigGroup.PLAN_FREE, "기록 보관 일수",
    "Free가 지난 기록을 볼 수 있는 기간. -1이면 무제한",
    ConfigValueType.INTEGER, List.of(), "-1"
  ),

  PRO_AI_IMAGE_GENERATION(
    ConfigGroup.PLAN_PRO, "AI 맞춤 삽화",
    "Pro에서 AI가 그린 맞춤 삽화를 쓸 수 있는지",
    ConfigValueType.BOOLEAN, List.of(), "true"
  ),
  PRO_ADS_REMOVED(
    ConfigGroup.PLAN_PRO, "광고 제거",
    "Pro에서 광고를 숨길지",
    ConfigValueType.BOOLEAN, List.of(), "true"
  ),
  PRO_ROUTINE_CREATE_PER_WEEK(
    ConfigGroup.PLAN_PRO, "주당 일과 생성 횟수",
    "Pro가 한 주에 만들 수 있는 일과 수. -1이면 무제한",
    ConfigValueType.INTEGER, List.of(), "-1"
  ),
  PRO_ROUTINE_MAX_COUNT(
    ConfigGroup.PLAN_PRO, "보유 일과 개수",
    "Pro가 동시에 가질 수 있는 일과 수. -1이면 무제한",
    ConfigValueType.INTEGER, List.of(), "-1"
  ),
  PRO_PROFILE_MAX_COUNT(
    ConfigGroup.PLAN_PRO, "이룸이 명수",
    "Pro 계정 하나에 둘 수 있는 이룸이 수. -1이면 무제한",
    ConfigValueType.INTEGER, List.of(), "-1"
  ),
  PRO_HISTORY_RETENTION_DAYS(
    ConfigGroup.PLAN_PRO, "기록 보관 일수",
    "Pro가 지난 기록을 볼 수 있는 기간. -1이면 무제한",
    ConfigValueType.INTEGER, List.of(), "-1"
  ),

  // 앱을 세우거나 업데이트를 요구하는 값들 (이슈 #279).
  //
  // ⚠️ 심사 기간에는 점검 모드를 켜지 않는다. 리뷰어가 점검 화면만 보고
  //    "앱이 동작하지 않는다"(App Store 2.1)로 돌려보낸다.
  MAINTENANCE_MODE(
    ConfigGroup.APP_CONTROL, "점검 모드",
    "켜면 서버가 API를 막고(503) 앱은 점검 안내 화면을 띄운다. 상태 확인·약관 읽기·토큰 갱신·관리자 화면은 열어 둔다. 심사 기간에는 켜지 않는다",
    ConfigValueType.BOOLEAN, List.of(), "false"
  ),
  MAINTENANCE_MESSAGE(
    ConfigGroup.APP_CONTROL, "점검 안내 문구",
    "점검 화면에 보여줄 말. 언제 끝나는지를 적어 준다",
    ConfigValueType.STRING, List.of(), "잠시 점검하고 있어요. 조금 뒤에 다시 열어주세요"
  ),
  // 버전 비교는 semver다. 1.10.0이 1.9.0보다 높다.
  MIN_APP_VERSION_IOS(
    ConfigGroup.APP_CONTROL, "iOS 최소 버전",
    "이 버전보다 낮으면 업데이트해야 쓸 수 있다. 비우면 막지 않는다",
    ConfigValueType.STRING, List.of(), ""
  ),
  MIN_APP_VERSION_ANDROID(
    ConfigGroup.APP_CONTROL, "Android 최소 버전",
    "이 버전보다 낮으면 업데이트해야 쓸 수 있다. 비우면 막지 않는다",
    ConfigValueType.STRING, List.of(), ""
  ),
  LATEST_APP_VERSION_IOS(
    ConfigGroup.APP_CONTROL, "iOS 최신 버전",
    "이 버전보다 낮으면 업데이트를 권한다. 건너뛸 수 있다",
    ConfigValueType.STRING, List.of(), ""
  ),
  LATEST_APP_VERSION_ANDROID(
    ConfigGroup.APP_CONTROL, "Android 최신 버전",
    "이 버전보다 낮으면 업데이트를 권한다. 건너뛸 수 있다",
    ConfigValueType.STRING, List.of(), ""
  ),
  // ── 앱이 서버에서 받아 쓰는 시간값 (앱 .env 에서 옮겨 왔다) ──
  // 앱은 시작할 때 /api/app/status 로 받아 저장해 두고, 못 받으면 코드 기본값을 쓴다.
  // 0 이나 음수는 "끝없이 기다리기"가 되므로 범위를 둔다. 단위는 모두 밀리초다.
  APP_CONNECT_TIMEOUT_MS(
    ConfigGroup.APP_TUNING, "서버 연결 대기",
    "앱이 서버에 연결을 맺기까지 기다리는 시간(ms). 넘기면 연결 실패로 본다. 1000~60000",
    ConfigValueType.INTEGER, List.of(), "10000", 1_000, 60_000
  ),
  APP_RECEIVE_TIMEOUT_MS(
    ConfigGroup.APP_TUNING, "서버 응답 대기",
    "연결 뒤 응답을 기다리는 시간(ms). 카드 생성이 오래 걸리므로 넉넉히 둔다. 5000~180000",
    ConfigValueType.INTEGER, List.of(), "60000", 5_000, 180_000
  ),
  APP_LOADING_MAX_WAIT_MS(
    ConfigGroup.APP_TUNING, "카드 만들기 최대 대기",
    "로딩 화면이 결과를 기다리는 최대 시간(ms). 넘기면 오류 코드와 다시 하기를 보여준다. 서버 응답 대기보다 짧게 둔다. 10000~180000",
    ConfigValueType.INTEGER, List.of(), "45000", 10_000, 180_000
  ),
  APP_CONSENT_FETCH_TIMEOUT_MS(
    ConfigGroup.APP_TUNING, "약관 불러오기 대기",
    "동의 화면이 약관을 기다리는 최대 시간(ms). 넘기면 앱에 담긴 약관을 보여준다. 로그인 직후라 짧게 둔다. 1000~15000",
    ConfigValueType.INTEGER, List.of(), "3000", 1_000, 15_000
  ),
  APP_DLP_MIN_DELAY_MS(
    ConfigGroup.APP_TUNING, "민감정보 검사 최소 연출",
    "검사 결과가 빨리 와도 이만큼은 검사 화면을 보여준다(ms). 0이면 연출하지 않는다. 0~10000",
    ConfigValueType.INTEGER, List.of(), "1500", 0, 10_000
  ),
  ;


  private final ConfigGroup group;
  private final String label;
  private final String description;
  private final ConfigValueType valueType;
  private final List<String> allowedValues;
  private final String defaultValue;
  /** INTEGER 의 허용 범위. 없으면(null) 범위를 보지 않는다 — 플랜 한도의 -1(무제한)처럼. */
  private final Integer minValue;
  private final Integer maxValue;

  ConfigKey(
    ConfigGroup group, String label, String description,
    ConfigValueType valueType, List<String> allowedValues, String defaultValue
  ) {
    this(group, label, description, valueType, allowedValues, defaultValue, null, null);
  }

  ConfigKey(
    ConfigGroup group, String label, String description,
    ConfigValueType valueType, List<String> allowedValues, String defaultValue,
    Integer minValue, Integer maxValue
  ) {
    this.group = group;
    this.label = label;
    this.description = description;
    this.valueType = valueType;
    this.allowedValues = allowedValues;
    this.defaultValue = defaultValue;
    this.minValue = minValue;
    this.maxValue = maxValue;
  }
}
