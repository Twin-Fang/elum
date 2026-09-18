package com.chuseok22.elumserver.ai.core;

import com.chuseok22.elumserver.systemconfig.core.ConfigKey;
import lombok.AllArgsConstructor;
import lombok.Getter;

/**
 * 카드 삽화를 만들 수 있는 제공자.
 *
 * <p>이름은 시스템 설정 {@code IMAGE_PROVIDER_SELECTED}의 허용값과 같아야 한다.
 */
@Getter
@AllArgsConstructor
public enum ImageProvider {

  GEMINI("Gemini", ConfigKey.PRICE_GEMINI_IMAGE_PER_IMAGE),
  OPENAI("OpenAI", ConfigKey.PRICE_OPENAI_IMAGE_PER_IMAGE),
  FLUX("FLUX (fal.ai)", ConfigKey.PRICE_FLUX_IMAGE_PER_IMAGE),
  ;

  private final String label;
  /// 장당 단가 설정 키. 제공자마다 달라 각 구현체가 자기 비용을 계산한다.
  private final ConfigKey priceKey;
}
