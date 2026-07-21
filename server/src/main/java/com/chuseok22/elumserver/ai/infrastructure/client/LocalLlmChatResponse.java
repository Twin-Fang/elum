package com.chuseok22.elumserver.ai.infrastructure.client;

import com.fasterxml.jackson.annotation.JsonIgnoreProperties;

// 서버 응답에 metrics 등 우리가 쓰지 않는 필드가 더 있으므로 알 수 없는 필드는 무시한다.
@JsonIgnoreProperties(ignoreUnknown = true)
public record LocalLlmChatResponse(
  String content,
  String model,
  boolean success
) {

}
