package com.chuseok22.elumserver.ai.application.service;

import com.chuseok22.elumserver.ai.core.PromptKey;
import com.chuseok22.elumserver.ai.core.SensitiveInfoCheckContent;
import com.chuseok22.elumserver.ai.core.SensitiveInfoCheckResult;
import com.chuseok22.elumserver.ai.infrastructure.client.LocalLlmChatRequest;
import com.chuseok22.elumserver.ai.infrastructure.client.LocalLlmChatResponse;
import com.chuseok22.elumserver.ai.infrastructure.client.LocalLlmClient;
import com.chuseok22.elumserver.common.infrastructure.exception.CustomException;
import com.chuseok22.elumserver.common.infrastructure.exception.ErrorCode;
import com.chuseok22.elumserver.common.infrastructure.properties.LocalLlmProperties;
import com.fasterxml.jackson.databind.ObjectMapper;
import java.util.List;
import java.util.Map;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Component;

@Slf4j
@Component
@RequiredArgsConstructor
public class SensitiveInfoGuardService {

  // Spring Boot 4.1은 Jackson 3(tools.jackson.databind) 기반이라 자동 구성되는 매핑 빈은
  // JsonMapper뿐이고 com.fasterxml.jackson.databind.ObjectMapper 빈은 존재하지 않는다.
  // JwtAuthenticationEntryPoint와 동일하게 직접 생성해서 사용한다.
  private final ObjectMapper objectMapper = new ObjectMapper();

  private final LocalLlmProperties localLlmProperties;
  private final LocalLlmClient localLlmClient;
  private final PromptTemplateService promptTemplateService;

  public SensitiveInfoCheckResult check(String text) {
    if (!localLlmProperties.enabled()) {
      return passThrough("local-llm.enabled=false로 설정되어 검증을 생략함", text);
    }

    String systemPrompt = promptTemplateService.getContent(PromptKey.LOCAL_LLM_SENSITIVE_INFO_CHECK);
    try {
      SensitiveInfoCheckContent content = callAndParse(systemPrompt, text);
      return new SensitiveInfoCheckResult(
        true, content.hasSensitiveInfo(), content.categories(), content.reason(), content.sanitizedText()
      );
    } catch (Exception e) {
      // 예외 메시지에는 검사 대상 원문 일부가 포함될 수 있으므로 예외 타입만 로그로 남긴다.
      log.warn("로컬 LLM 민감정보 검증 실패, fail-open으로 통과 처리함: {}", e.getClass().getSimpleName());
      return passThrough("검증 실패로 통과 처리됨", text);
    }
  }

  // 관리자 테스트 전용: local-llm.enabled 플래그와 fail-open 정책을 모두 우회하고 로컬 LLM을
  // 항상 직접 호출한다. enabled=false 상태에서도 관리자가 실제 탐지 성능을 검증할 수 있어야
  // 하고, 실패 시에도 마스킹 없이 통과된 것처럼 감추지 않고 에러를 그대로 노출해야 하기 때문이다.
  public SensitiveInfoCheckResult checkForTest(String systemPrompt, String text) {
    try {
      SensitiveInfoCheckContent content = callAndParse(systemPrompt, text);
      return new SensitiveInfoCheckResult(
        true, content.hasSensitiveInfo(), content.categories(), content.reason(), content.sanitizedText()
      );
    } catch (Exception e) {
      log.warn("[관리자 테스트] 로컬 LLM 민감정보 검증 실패: {}", e.getClass().getSimpleName());
      throw new CustomException(ErrorCode.PROMPT_TEST_LOCAL_LLM_FAILED);
    }
  }

  private SensitiveInfoCheckContent callAndParse(String systemPrompt, String text) throws Exception {
    LocalLlmChatRequest request = new LocalLlmChatRequest(
      localLlmProperties.model(), wrapAsData(text), systemPrompt, 0, responseFormat()
    );
    LocalLlmChatResponse response = localLlmClient.chat(request);

    if (response == null || !response.success()) {
      throw new IllegalStateException("로컬 LLM 응답 success=false");
    }

    SensitiveInfoCheckContent content = objectMapper.readValue(response.content(), SensitiveInfoCheckContent.class);

    // hasSensitiveInfo는 Boolean(박싱 타입)으로 선언해 필드 누락 시 Jackson이 false로
    // 임의 채우지 않고 null로 남도록 했다 — 그래야 스키마 위반을 놓치지 않는다.
    if (content.categories() == null || content.reason() == null
      || content.hasSensitiveInfo() == null || content.sanitizedText() == null) {
      throw new IllegalStateException("로컬 LLM 응답이 JSON Schema를 따르지 않음");
    }

    return content;
  }

  private String wrapAsData(String text) {
    return "<text>" + text + "</text>";
  }

  // fail-open 시 마스킹 없이 원문을 그대로 sanitizedText로 반환한다 — 검증 실패를 이유로
  // 서비스를 막지 않되, 이 경우 마스킹 없이 원문이 그대로 다음 단계(외부 AI)로 전달된다.
  private SensitiveInfoCheckResult passThrough(String reason, String originalText) {
    return new SensitiveInfoCheckResult(false, false, List.of(), reason, originalText);
  }

  private Map<String, Object> responseFormat() {
    return Map.of(
      "type", "object",
      "properties", Map.of(
        "hasSensitiveInfo", Map.of("type", "boolean"),
        "categories", Map.of("type", "array", "items", Map.of("type", "string")),
        "reason", Map.of("type", "string"),
        "sanitizedText", Map.of("type", "string")
      ),
      "required", List.of("hasSensitiveInfo", "categories", "reason", "sanitizedText")
    );
  }
}
