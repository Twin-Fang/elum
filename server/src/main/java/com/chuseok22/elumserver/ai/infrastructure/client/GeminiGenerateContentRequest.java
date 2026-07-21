package com.chuseok22.elumserver.ai.infrastructure.client;

import com.fasterxml.jackson.annotation.JsonInclude;
import java.util.List;
import java.util.Map;

// GeminiImageClient(Task 3)는 systemInstruction/generationConfig 없이 호출하므로 이 값들이
// null이 되는데, "systemInstruction":null처럼 명시적으로 전송하지 않도록 NON_NULL로
// 직렬화 시 생략한다.
@JsonInclude(JsonInclude.Include.NON_NULL)
public record GeminiGenerateContentRequest(
  GeminiSystemInstruction systemInstruction,
  List<GeminiContent> contents,
  Map<String, Object> generationConfig
) {

  public record GeminiSystemInstruction(List<GeminiPart> parts) {

  }

  public record GeminiContent(String role, List<GeminiPart> parts) {

  }

  public record GeminiPart(String text) {

  }
}
