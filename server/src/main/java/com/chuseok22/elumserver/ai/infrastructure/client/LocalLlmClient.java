package com.chuseok22.elumserver.ai.infrastructure.client;

import com.chuseok22.elumserver.ai.application.service.AiCallLogService;
import com.chuseok22.elumserver.ai.core.AiCallType;
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
  private final AiCallLogService aiCallLogService;

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
      long elapsedMs = System.currentTimeMillis() - startedAt;
      log.info(
        "로컬 LLM 호출 완료: elapsedMs={}, model={}, success={}, content={}",
        elapsedMs,
        response != null ? response.model() : null,
        response != null && response.success(),
        response != null ? response.content() : null
      );
      // HTTP는 성공했어도 응답 자체가 success=false면 실패로 기록한다.
      if (response != null && response.success()) {
        aiCallLogService.recordSuccess(AiCallType.LOCAL_LLM_DLP, request.model(), elapsedMs, null);
      } else {
        aiCallLogService.recordFailure(
          AiCallType.LOCAL_LLM_DLP, request.model(), elapsedMs, "로컬 LLM 응답 success=false"
        );
      }
      return response;
    } catch (Exception e) {
      long elapsedMs = System.currentTimeMillis() - startedAt;
      log.warn(
        "로컬 LLM 호출 실패: elapsedMs={}, model={}, system={}, prompt={}",
        elapsedMs, request.model(), request.system(), request.prompt(), e
      );
      aiCallLogService.recordFailure(AiCallType.LOCAL_LLM_DLP, request.model(), elapsedMs, e.getMessage());
      throw e;
    }
  }
}
