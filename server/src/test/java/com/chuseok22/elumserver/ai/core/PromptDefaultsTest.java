package com.chuseok22.elumserver.ai.core;

import static org.assertj.core.api.Assertions.assertThat;

import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;

class PromptDefaultsTest {

  @Test
  @DisplayName("4개 Gemini 프롬프트 키 모두 기본값이 존재하고 비어있지 않다")
  void defaults_geminiKeys_allPresentAndNotBlank() {
    assertThat(PromptDefaults.DEFAULTS.get(PromptKey.GEMINI_ROUTINE_CREATE_PREFIX)).isNotBlank();
    assertThat(PromptDefaults.DEFAULTS.get(PromptKey.GEMINI_ROUTINE_REVISE_PREFIX)).isNotBlank();
    assertThat(PromptDefaults.DEFAULTS.get(PromptKey.GEMINI_ROUTINE_QUESTION_PREFIX)).isNotBlank();
    assertThat(PromptDefaults.DEFAULTS.get(PromptKey.GEMINI_ROUTINE_IMAGE_PREFIX)).isNotBlank();
  }

  @Test
  @DisplayName("루틴 생성 프롬프트는 JSON 필드 이름을 명시한다")
  void createPrompt_mentionsJsonFields() {
    String content = PromptDefaults.DEFAULTS.get(PromptKey.GEMINI_ROUTINE_CREATE_PREFIX);

    assertThat(content).contains("routineText").contains("additionalAnswers").contains("supportGoals");
  }

  @Test
  @DisplayName("루틴 수정 프롬프트는 최소 변경 원칙과 previousRoutine 필드를 명시한다")
  void revisePrompt_mentionsMinimalChangePolicy() {
    String content = PromptDefaults.DEFAULTS.get(PromptKey.GEMINI_ROUTINE_REVISE_PREFIX);

    assertThat(content).contains("previousRoutine").contains("최소 변경");
  }

  @Test
  @DisplayName("질문 생성 프롬프트는 supportGoal 필드와 직접 입력 금지를 명시한다")
  void questionPrompt_mentionsSupportGoalAndBansManualInput() {
    String content = PromptDefaults.DEFAULTS.get(PromptKey.GEMINI_ROUTINE_QUESTION_PREFIX);

    assertThat(content).contains("supportGoal").contains("직접 입력");
  }

  @Test
  @DisplayName("이미지 프롬프트는 캐릭터 일관성과 글자 금지를 명시한다")
  void imagePrompt_mentionsCharacterConsistencyAndNoText() {
    String content = PromptDefaults.DEFAULTS.get(PromptKey.GEMINI_ROUTINE_IMAGE_PREFIX);

    assertThat(content).contains("캐릭터").contains("글자");
  }
}
