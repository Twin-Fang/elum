package com.chuseok22.elumserver.ai.core;

import static org.assertj.core.api.Assertions.assertThat;

import java.util.Arrays;
import java.util.List;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;

class PromptKeyTest {

  @Test
  @DisplayName("언어마다 다른 행이 필요한 키는 글 생성·질문·그림 문장 번역 넷뿐이다")
  void localizedKeys() {
    List<PromptKey> localized = Arrays.stream(PromptKey.values()).filter(PromptKey::isLocalized).toList();

    assertThat(localized).containsExactly(
      PromptKey.GEMINI_ROUTINE_CREATE_PREFIX,
      PromptKey.GEMINI_ROUTINE_QUESTION_PREFIX,
      PromptKey.FLUX_IMAGE_PROMPT_TRANSLATE,
      PromptKey.REALISTIC_IMAGE_PROMPT_TRANSLATE);
  }

  @Test
  @DisplayName("그림 지시문과 로컬 LLM 검사는 언어와 무관하다 — ko 행 하나만 둔다")
  void neutralKeys() {
    assertThat(PromptKey.GEMINI_ROUTINE_IMAGE_PREFIX.isLocalized()).isFalse();
    assertThat(PromptKey.ROUTINE_IMAGE_PREFIX_EN.isLocalized()).isFalse();
    assertThat(PromptKey.FLUX_ROUTINE_IMAGE_PREFIX.isLocalized()).isFalse();
    assertThat(PromptKey.REALISTIC_ROUTINE_IMAGE_PREFIX.isLocalized()).isFalse();
    assertThat(PromptKey.LOCAL_LLM_SENSITIVE_INFO_CHECK.isLocalized()).isFalse();
  }
}
