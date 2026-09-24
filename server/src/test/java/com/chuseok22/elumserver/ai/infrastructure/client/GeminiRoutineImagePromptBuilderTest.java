package com.chuseok22.elumserver.ai.infrastructure.client;

import static org.assertj.core.api.Assertions.assertThat;

import com.chuseok22.elumserver.ai.core.ImagePromptLanguage;
import com.chuseok22.elumserver.member.infrastructure.entity.CharacterType;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;

class GeminiRoutineImagePromptBuilderTest {

  private final GeminiRoutineImagePromptBuilder builder = new GeminiRoutineImagePromptBuilder();

  @Test
  @DisplayName("prefix 뒤에 장면 정보 JSON을 붙이고, 참조 이미지를 보내면 그렇다고 적는다")
  void build_withCharacter_appendsSceneJsonWithReferenceFlag() {
    String result = builder.build("스타일 규칙", "가방에 물통을 넣어요.", CharacterType.LULU, true);

    assertThat(result).startsWith("스타일 규칙");
    assertThat(result).contains("\"task\":\"CREATE_ROUTINE_CARD_IMAGE\"");
    assertThat(result).contains("\"stepDescription\":\"가방에 물통을 넣어요.\"");
    assertThat(result).contains("\"type\":\"LULU\"");
    assertThat(result).contains("\"referenceImageProvided\":true");
  }

  @Test
  @DisplayName("생김새를 함께 싣는다 — 참조 이미지를 못 보내는 제공자는 이것만 보고 그린다 (#269)")
  void build_includesAppearance() {
    String result = builder.build("스타일 규칙", "옷을 입어요.", CharacterType.LULU, false);

    // 이름만 보내면 LULU가 무엇인지 알 수 없어 사람이 그려졌다.
    assertThat(result).contains("\"appearance\"");
    assertThat(result).contains(CharacterType.LULU.getAppearance());
    assertThat(result).contains("\"referenceImageProvided\":false");
  }

  @Test
  @DisplayName("포포도 자기 생김새를 싣는다")
  void build_popoAppearance() {
    String result = builder.build("스타일 규칙", "손을 씻어요.", CharacterType.POPO, false);

    assertThat(result).contains(CharacterType.POPO.getAppearance());
    assertThat(result).doesNotContain(CharacterType.LULU.getAppearance());
  }

  @Test
  @DisplayName("캐릭터가 없으면 character 필드 자체가 생략된다")
  void build_withoutCharacter_omitsCharacterField() {
    String result = builder.build("스타일 규칙", "옷을 입어요.", null, false);

    assertThat(result).doesNotContain("\"character\"");
  }

  @Test
  @DisplayName("영어 지시문이면 장면 라벨과 생김새도 영어로 싣는다 — 한국어가 섞이면 토큰이 다시 늘어난다 (#375)")
  void build_english_usesEnglishLabelAndAppearance() {
    String result = builder.build(
      "Style rules", "옷을 입어요.", CharacterType.LULU, false, ImagePromptLanguage.EN);

    assertThat(result).startsWith("Style rules\n\nScene info:\n");
    assertThat(result).contains(CharacterType.LULU.getAppearanceEn());
    assertThat(result).doesNotContain(CharacterType.LULU.getAppearance());
    assertThat(result).doesNotContain("장면 정보");
    // 카드 설명은 한국어 그대로 간다 — OpenAI·Gemini 는 알아듣고, 짧다.
    assertThat(result).contains("\"stepDescription\":\"옷을 입어요.\"");
  }

  @Test
  @DisplayName("언어를 말하지 않으면 지금과 같은 한국어 조립이다")
  void build_defaultIsKorean() {
    assertThat(builder.build("스타일 규칙", "옷을 입어요.", CharacterType.LULU, false))
      .isEqualTo(builder.build("스타일 규칙", "옷을 입어요.", CharacterType.LULU, false, ImagePromptLanguage.KO));
  }
}
