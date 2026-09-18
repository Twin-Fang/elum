package com.chuseok22.elumserver.systemconfig.core;

import java.util.List;
import lombok.AllArgsConstructor;
import lombok.Getter;

// 동적으로 수정 가능한 시스템 설정의 전체 목록. 새 설정이 필요하면 여기에 키를 추가하면
// SystemConfigInitializer가 기본값을 시딩하고 관리자 화면에 자동으로 노출된다.
// 모델명 3종의 defaultValue는 코드 기본값이며, 배포 환경(yml)에 값이 있으면
// SystemConfigService.defaultValueFor()가 그 값을 우선한다.
@Getter
@AllArgsConstructor
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
  ;


  private final ConfigGroup group;
  private final String label;
  private final String description;
  private final ConfigValueType valueType;
  private final List<String> allowedValues;
  private final String defaultValue;
}
