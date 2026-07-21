package com.chuseok22.elumserver.ai.infrastructure.client;

import com.chuseok22.elumserver.common.infrastructure.properties.LocalLlmProperties;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Component;
import org.springframework.web.client.RestClient;

@Slf4j
@Component
@RequiredArgsConstructor
public class LocalLlmClient {

  private final RestClient localLlmRestClient;
  private final LocalLlmProperties localLlmProperties;

  public LocalLlmChatResponse chat(LocalLlmChatRequest request) {
    long startedAt = System.currentTimeMillis();
    log.info(
      "로컬 LLM 호출 시작: chatPath={}, model={}, system={}, prompt={}",
      localLlmProperties.chatPath(),
      request.model(), request.system(), request.prompt()
    );
    try {
      LocalLlmChatResponse response = localLlmRestClient.post()
        .uri(localLlmProperties.chatPath())
        .header("X-API-Key", localLlmProperties.apiKey())
        .body(request)
        .retrieve()
        .body(LocalLlmChatResponse.class);
      log.info(
        "로컬 LLM 호출 완료: elapsedMs={}, model={}, success={}, content={}",
        System.currentTimeMillis() - startedAt,
        response != null ? response.model() : null,
        response != null && response.success(),
        response != null ? response.content() : null
      );
      return response;
    } catch (Exception e) {
      log.warn(
        "로컬 LLM 호출 실패: elapsedMs={}, model={}, system={}, prompt={}",
        System.currentTimeMillis() - startedAt, request.model(), request.system(), request.prompt(), e
      );
      throw e;
    }
  }
}
