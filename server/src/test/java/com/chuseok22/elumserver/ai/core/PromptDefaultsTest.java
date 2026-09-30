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

  @Test
  @DisplayName("영어 그림 지시문은 한국어 없이 같은 규칙을 담는다 — 같은 지시가 토큰 1/3 이다 (#375)")
  void englishImagePrompt_hasNoKoreanAndKeepsRules() {
    String content = PromptDefaults.DEFAULTS.get(PromptKey.ROUTINE_IMAGE_PREFIX_EN);

    assertThat(content).isNotBlank();
    assertThat(content).doesNotContainPattern("[가-힣]");
    // 빌더가 싣는 필드 이름과 장면 라벨을 가리켜야 모델이 무엇을 따를지 안다.
    assertThat(content).contains("character.appearance").contains("scene.stepDescription")
      .contains("Scene info");
    assertThat(content.toLowerCase()).contains("text").contains("speech bubble");
    // 한국어판보다 짧아야 줄이는 의미가 있다(글자 수가 아니라 토큰이 목적이지만 최소한의 확인).
    assertThat(content.length()).isLessThan(
      PromptDefaults.DEFAULTS.get(PromptKey.GEMINI_ROUTINE_IMAGE_PREFIX).length() * 2);
  }

  @Test
  @DisplayName("글 응답은 공백 없는 한 줄 JSON 으로 달라고 한다 — 들여쓰기 공백도 출력 토큰이다 (#375)")
  void textPrompts_askForCompactJson() {
    for (PromptKey key : new PromptKey[]{
        PromptKey.GEMINI_ROUTINE_CREATE_PREFIX, PromptKey.GEMINI_ROUTINE_QUESTION_PREFIX}) {
      assertThat(PromptDefaults.DEFAULTS.get(key)).as(key.name())
        .contains("공백과 줄바꿈 없이 한 줄로");
    }
  }

  @Test
  @DisplayName("FLUX 지시문은 짧은 영어 — 글자를 부르는 말(card·disabilities)이 없고 글자 금지를 적는다 (#373)")
  void fluxPrompt_shortEnglishWithoutTextInvitingWords() {
    String content = PromptDefaults.DEFAULTS.get(PromptKey.FLUX_ROUTINE_IMAGE_PREFIX);

    assertThat(content).doesNotContainPattern("[가-힣]");
    assertThat(content.toLowerCase()).doesNotContain("card").doesNotContain("disabilit")
      .doesNotContain("children").contains("no letters");
    // 2차 시험의 지시문 길이 수준. 길어지면 schnell 이 그림 속 글자로 찍는다.
    assertThat(content.length()).isLessThan(400);
  }

  @Test
  @DisplayName("번역 지시문은 'The character' 주어와 물건 상태를 요구하고 글자를 부르는 말을 막는다 (#373)")
  void translatePrompt_asksSubjectAndConcreteObjects() {
    String content = PromptDefaults.DEFAULTS.get(PromptKey.FLUX_IMAGE_PROMPT_TRANSLATE);

    assertThat(content).doesNotContainPattern("[가-힣]");
    assertThat(content).contains("The character").contains("imagePromptEn");
    assertThat(content.toLowerCase()).contains("letters").contains("cards");
  }


  // ── 실사 방식 (#457) ────────────────────────────────────────────────

  @Test
  @DisplayName("모든 프롬프트 키에 기본값이 있다 — 새 키가 시딩에서 빠지면 첫 기동 때 비어 있다")
  void everyKeyHasDefault() {
    assertThat(PromptDefaults.DEFAULTS).hasSize(PromptKey.values().length);
    for (PromptKey key : PromptKey.values()) {
      assertThat(PromptDefaults.DEFAULTS.get(key)).as(key.name()).isNotBlank();
    }
    assertThat(PromptDefaults.DEFAULTS).hasSize(9);
  }

  @Test
  @DisplayName("실사 그림 지시문은 캐릭터 관례가 없다 — 참조 이미지·생김새·Only one character·플랫 벡터·파스텔 지시가 없다")
  void realisticPrefix_hasNoCharacterOrCartoonInstruction() {
    String content = PromptDefaults.DEFAULTS.get(PromptKey.REALISTIC_ROUTINE_IMAGE_PREFIX);

    assertThat(content).isNotBlank().doesNotContainPattern("[가-힣]");
    assertThat(content)
      .doesNotContain("character.appearance")
      .doesNotContain("reference image")
      .doesNotContain("Only one character")
      .doesNotContain("The character")
      .doesNotContain("pastel")
      .doesNotContain("Simple flat vector")
      .doesNotContain("[Character")
      .doesNotContain("cartoon");
    // 사진 같은 그림·물건 하나·글자 없음은 남아 있어야 한다 (긍정문 태그)
    assertThat(content).contains("realistic photo").contains("One single object").contains("No text");
  }

  @Test
  @DisplayName("실사 지시문·번역 지시문에 card·sign·hands·label 단어가 없다 — FLUX schnell 이 그 단어를 그대로 그렸다")
  void realisticPrompts_avoidWordsThatFluxDraws() {
    // 1차 실측(fal-ai/flux/schnell)에서 'One card, one action'·'signs, labels'·'show only hands'·'Never draw ...' 의
    // 단어가 그림에 나왔다(카드를 든 손·금지 표시·로고·글자). 부정문도 schnell 은 무시하고 단어를 그린다.
    for (PromptKey key : new PromptKey[]{
      PromptKey.REALISTIC_ROUTINE_IMAGE_PREFIX, PromptKey.REALISTIC_IMAGE_PROMPT_TRANSLATE}) {
      String lower = PromptDefaults.DEFAULTS.get(key).toLowerCase();
      assertThat(lower).as(key.name())
        .doesNotContain("card").doesNotContain("sign").doesNotContain("hand").doesNotContain("label")
        .doesNotContain("logo").doesNotContain("never");
    }
  }

  @Test
  @DisplayName("실사 번역 지시문은 The character 로 시작하라고 하지 않는다 — 물건 하나, 고정 문장 형식, 30단어 미만")
  void realisticTranslate_isObjectCentered() {
    String content = PromptDefaults.DEFAULTS.get(PromptKey.REALISTIC_IMAGE_PROMPT_TRANSLATE);

    assertThat(content).doesNotContain("Start with \"The character\"").doesNotContain("The character");
    assertThat(content).contains("imagePromptEn").contains("Under 25 words");
    assertThat(content).contains("A {object and its state} on a plain light gray surface.");
  }

  @Test
  @DisplayName("실사 지시문에도 아이·아동 호칭이 없다 (이슈 #197)")
  void realisticPrompts_doNotAddressUserAsChild() {
    for (PromptKey key : new PromptKey[]{
      PromptKey.REALISTIC_ROUTINE_IMAGE_PREFIX, PromptKey.REALISTIC_IMAGE_PROMPT_TRANSLATE}) {
      assertThat(PromptDefaults.DEFAULTS.get(key)).as(key.name())
        .doesNotContain("아이").doesNotContain("아동").doesNotContain("child").doesNotContain("kid");
    }
  }

  @Test
  @DisplayName("만화 쪽 기본값은 그대로다 — 실사 추가가 기존 지시문을 건드리지 않는다")
  void cartoonPrompts_keepCharacterConvention() {
    assertThat(PromptDefaults.DEFAULTS.get(PromptKey.FLUX_IMAGE_PROMPT_TRANSLATE)).contains("Start with \"The character\"");
    assertThat(PromptDefaults.DEFAULTS.get(PromptKey.ROUTINE_IMAGE_PREFIX_EN)).contains("[Character - required]");
  }

  /**
   * 이슈 #453 — 카드 설명(description)이 길어 이해하기 어렵다는 현장 피드백.
   *
   * <p>서버에서 글자 수를 자르지 않고 <b>AI에게 짧게 쓰라고 요청</b>해서 푼다.
   * 프롬프트의 예시가 그대로 길이 기준이 되므로 예시도 짧아야 한다.
   */
  @Test
  @DisplayName("루틴 생성 프롬프트는 설명을 짧은 한 문장으로 요청하고 긴 예시를 두지 않는다 (이슈 #453)")
  void createPrompt_asksForShortDescription() {
    String content = PromptDefaults.DEFAULTS.get(PromptKey.GEMINI_ROUTINE_CREATE_PREFIX);

    assertThat(content)
        .contains("12자 안팎")
        .contains("조심히")
        .doesNotContain("조금 더 자세")
        .doesNotContain("학교에 입고 갈 옷을 차례대로 입어요")
        .doesNotContain("잠옷을 벗고 학교에 입고 갈 옷으로 갈아입어요");
  }
}
