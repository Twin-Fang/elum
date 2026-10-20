package com.chuseok22.elumserver.ai.infrastructure.client;

import com.chuseok22.elumserver.member.infrastructure.entity.CharacterType;
import com.fasterxml.jackson.annotation.JsonInclude;

// character가 null이면(캐릭터 미선택 회원) 필드 자체를 생략한다 — GeminiGenerateContentRequest와
// 동일한 NON_NULL 관례를 따른다.
@JsonInclude(JsonInclude.Include.NON_NULL)
public record GeminiImageAiInput(String task, Scene scene, Character character) {

  /// routineTitle·stepTitle·sceneDetail 은 없으면 생략 (설명만 있는 카드는 예전 JSON 그대로)
  @JsonInclude(JsonInclude.Include.NON_NULL)
  public record Scene(String routineTitle, String stepTitle, String stepDescription, String sceneDetail) {

    public Scene(String stepDescription) {
      this(null, null, stepDescription, null);
    }
  }

  /**
   * @param appearance 그려야 할 생김새. 참조 이미지를 못 보내는 제공자는 이것만 보고 그린다
   */
  public record Character(
    CharacterType type, String appearance, boolean referenceImageProvided
  ) {

  }
}
