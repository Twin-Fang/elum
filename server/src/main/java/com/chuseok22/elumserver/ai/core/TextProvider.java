package com.chuseok22.elumserver.ai.core;

import com.chuseok22.elumserver.systemconfig.core.ConfigKey;
import lombok.AllArgsConstructor;
import lombok.Getter;

/**
 * 일과·추가 질문 텍스트를 만들 수 있는 제공자.
 *
 * <p>이름은 시스템 설정 {@code TEXT_PROVIDER_SELECTED}의 허용값과 같아야 한다.
 *
 * <p>이미지({@link ImageProvider})와 달리 단가 키가 둘이다 — 텍스트는 장당이 아니라
 * 입력·출력 토큰을 따로 셈하기 때문이다.
 */
@Getter
@AllArgsConstructor
public enum TextProvider {

  GEMINI(
    "Gemini",
    ConfigKey.PRICE_GEMINI_TEXT_INPUT_PER_1M,
    ConfigKey.PRICE_GEMINI_TEXT_OUTPUT_PER_1M
  ),
  OPENAI(
    "OpenAI",
    ConfigKey.PRICE_OPENAI_TEXT_INPUT_PER_1M,
    ConfigKey.PRICE_OPENAI_TEXT_OUTPUT_PER_1M
  ),
  ;

  private final String label;
  private final ConfigKey inputPriceKey;
  private final ConfigKey outputPriceKey;
}
