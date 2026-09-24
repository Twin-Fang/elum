package com.chuseok22.elumserver.ai.core;

import lombok.AllArgsConstructor;
import lombok.Getter;

/**
 * OpenAI·Gemini 그림 지시문의 언어 (#375).
 *
 * <p>같은 지시를 영어로 쓰면 토큰이 약 1/3 이다(지시문+루루 606 → 180, tiktoken 실측). OpenAI 그림은
 * 입력 글자도 토큰으로 받으므로 장당 약 22% 가 싸진다. 다만 운영 DB 의 프롬프트는 배포로 바뀌지
 * 않고, 바꾸기 전에 같은 카드를 두 언어로 그려 보고 정해야 해서 <b>관리자 설정으로 고른다.</b>
 * 기본값은 지금과 같은 KO 다.
 *
 * <p>FLUX 는 이 값과 무관하다 — 한국어를 못 알아들어 전용 영어 지시문을 따로 쓴다 (#373).
 */
@Getter
@AllArgsConstructor
public enum ImagePromptLanguage {

  KO(PromptKey.GEMINI_ROUTINE_IMAGE_PREFIX, "장면 정보"),
  EN(PromptKey.ROUTINE_IMAGE_PREFIX_EN, "Scene info"),
  ;

  /// 이 언어의 지시문이 들어 있는 프롬프트 키.
  private final PromptKey prefixKey;
  /// 지시문 뒤에 붙는 장면 JSON 의 머리말. 지시문이 이 이름으로 장면을 가리킨다.
  private final String sceneLabel;

  /// 설정값을 읽는다. 모르는 값이면 KO — 설정이 망가져도 지금 동작으로 돌아간다.
  public static ImagePromptLanguage from(String raw) {
    if (raw != null && "EN".equals(raw.trim())) {
      return EN;
    }
    return KO;
  }
}
