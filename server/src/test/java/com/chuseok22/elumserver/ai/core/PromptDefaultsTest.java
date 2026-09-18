package com.chuseok22.elumserver.ai.core;

import static org.assertj.core.api.Assertions.assertThat;

import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;

class PromptDefaultsTest {

  @Test
  @DisplayName("3개 Gemini 프롬프트 키 모두 기본값이 존재하고 비어있지 않다")
  void defaults_geminiKeys_allPresentAndNotBlank() {
    assertThat(PromptDefaults.DEFAULTS.get(PromptKey.GEMINI_ROUTINE_CREATE_PREFIX)).isNotBlank();
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

  /**
   * 이슈 #197 — 사용자를 아이/아동으로 부르지 않는다.
   *
   * <p>타겟은 연령으로 나누지 않는다. 20대 당사자가 자기 휴대폰에서 카드를 본다.
   * 화면 문구만 고치면 <b>AI가 만든 문장에서 다시 새어 나온다.</b>
   */
  @Test
  @DisplayName("AI에게 주는 지시에 나이를 짐작하게 하는 표현이 없다 (이슈 #197)")
  void prompts_doNotAddressUserAsChild() {
    for (PromptKey key : new PromptKey[]{
        PromptKey.GEMINI_ROUTINE_CREATE_PREFIX,
        PromptKey.GEMINI_ROUTINE_QUESTION_PREFIX,
        PromptKey.GEMINI_ROUTINE_IMAGE_PREFIX}) {
      String content = PromptDefaults.DEFAULTS.get(key);

      assertThat(content)
          .as("%s — AI에게 아이처럼 말하라고 지시하면 안 된다", key)
          .doesNotContain("아이에게 말하듯")
          .doesNotContain("아이 친화적")
          .doesNotContain("발달장애 아동")
          .doesNotContain("아동이 스스로")
          .doesNotContain("일반적인 아동");
    }
  }

  /**
   * 이슈 #197 — DLP 판별 규칙의 "아이"/"아동"은 <b>지우면 안 된다</b>.
   *
   * <p>보호자는 실제로 "우리 아이가…"라고 입력한다. 이 목록이 사라지면 그 단어를
   * 사람 이름으로 오인해 마스킹이 오작동한다. 말투를 고치다 함께 지워지는 것을 막는다.
   */
  @Test
  @DisplayName("DLP 판별 규칙의 아이·아동 목록은 그대로 남아 있다 (이슈 #197)")
  void dlpPrompt_keepsChildWordsAsNonNameExamples() {
    String content = PromptDefaults.DEFAULTS.get(PromptKey.LOCAL_LLM_SENSITIVE_INFO_CHECK);

    assertThat(content).contains("\"아이\", \"아동\"").contains("이름이 아닙니다");
  }
}
