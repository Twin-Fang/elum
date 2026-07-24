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
  ;

  private final ConfigGroup group;
  private final String label;
  private final String description;
  private final ConfigValueType valueType;
  private final List<String> allowedValues;
  private final String defaultValue;
}
