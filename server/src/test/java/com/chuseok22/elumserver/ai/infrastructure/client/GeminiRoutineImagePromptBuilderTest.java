package com.chuseok22.elumserver.ai.infrastructure.client;

import static org.assertj.core.api.Assertions.assertThat;

import com.chuseok22.elumserver.member.infrastructure.entity.CharacterType;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;

class GeminiRoutineImagePromptBuilderTest {

  private final GeminiRoutineImagePromptBuilder builder = new GeminiRoutineImagePromptBuilder();

  @Test
  @DisplayName("prefix 뒤에 장면 정보 JSON을 붙이고, 캐릭터가 있으면 referenceImageProvided가 true다")
  void build_withCharacter_appendsSceneJsonWithReferenceFlag() {
    String result = builder.build("스타일 규칙", "가방에 물통을 넣어요.", CharacterType.LULU);

    assertThat(result).startsWith("스타일 규칙");
    assertThat(result).contains("\"task\":\"CREATE_ROUTINE_CARD_IMAGE\"");
    assertThat(result).contains("\"stepDescription\":\"가방에 물통을 넣어요.\"");
    assertThat(result).contains("\"type\":\"LULU\"");
    assertThat(result).contains("\"referenceImageProvided\":true");
  }

  @Test
  @DisplayName("캐릭터가 없으면 character 필드 자체가 생략된다")
  void build_withoutCharacter_omitsCharacterField() {
    String result = builder.build("스타일 규칙", "옷을 입어요.", null);

    assertThat(result).doesNotContain("\"character\"");
  }
}
