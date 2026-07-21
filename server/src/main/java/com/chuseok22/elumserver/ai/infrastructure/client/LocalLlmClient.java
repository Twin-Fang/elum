package com.chuseok22.elumserver.ai.infrastructure.client;

import com.chuseok22.elumserver.common.infrastructure.properties.LocalLlmProperties;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Component;
import org.springframework.web.client.RestClient;

@Component
@RequiredArgsConstructor
public class LocalLlmClient {

  private final RestClient localLlmRestClient;
  private final LocalLlmProperties localLlmProperties;

  public LocalLlmChatResponse chat(LocalLlmChatRequest request) {
    return localLlmRestClient.post()
      .uri(localLlmProperties.chatPath())
      .header("X-API-Key", localLlmProperties.apiKey())
      .body(request)
      .retrieve()
      .body(LocalLlmChatResponse.class);
  }
}
