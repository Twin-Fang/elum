package com.chuseok22.elumserver.ai.infrastructure.client;

import com.chuseok22.elumserver.member.infrastructure.entity.CharacterType;
import com.fasterxml.jackson.annotation.JsonInclude;

// character가 null이면(캐릭터 미선택 회원) 필드 자체를 생략한다 — GeminiGenerateContentRequest와
// 동일한 NON_NULL 관례를 따른다.
@JsonInclude(JsonInclude.Include.NON_NULL)
public record GeminiImageAiInput(String task, Scene scene, Character character) {

  public record Scene(String stepDescription) {

  }

  public record Character(CharacterType type, boolean referenceImageProvided) {

  }
}
