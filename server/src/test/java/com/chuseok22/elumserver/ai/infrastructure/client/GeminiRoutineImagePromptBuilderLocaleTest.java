package com.chuseok22.elumserver.ai.infrastructure.client;

import static org.assertj.core.api.Assertions.assertThat;

import com.chuseok22.elumserver.ai.core.ImagePromptLanguage;
import com.chuseok22.elumserver.member.infrastructure.entity.CharacterType;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;

/**
 * 그림 지시문 언어(ImagePromptLanguage)와 일과 언어는 별개다. 카드 설명이 어떤 언어든 그대로 실리고,
 * 장면 머리말은 관리자 설정(KO/EN)만 따른다.
 */
class GeminiRoutineImagePromptBuilderLocaleTest {

  private final GeminiRoutineImagePromptBuilder builder = new GeminiRoutineImagePromptBuilder();

  @Test
  @DisplayName("일본어 카드 설명은 KO 지시문에도 글자 그대로 실린다 — 머리말은 설정을 따른다")
  void japaneseDescription_withKoInstruction() {
    String prompt = builder.build("PREFIX", "傘を持ちます", CharacterType.LULU, false, ImagePromptLanguage.KO);

    assertThat(prompt).startsWith("PREFIX").contains("장면 정보:").contains("傘を持ちます");
  }

  @Test
  @DisplayName("중국어·스페인어 카드 설명도 EN 지시문에 그대로 실린다")
  void otherDescriptions_withEnInstruction() {
    assertThat(builder.build("PREFIX", "带上雨伞", CharacterType.LULU, false, ImagePromptLanguage.EN))
      .contains("Scene info:").contains("带上雨伞");
    assertThat(builder.build("PREFIX", "Saca el paraguas", CharacterType.LULU, false, ImagePromptLanguage.EN))
      .contains("Scene info:").contains("Saca el paraguas");
  }
}
