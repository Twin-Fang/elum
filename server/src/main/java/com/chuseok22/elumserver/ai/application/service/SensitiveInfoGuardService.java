package com.chuseok22.elumserver.ai.application.service;

import com.chuseok22.elumserver.ai.core.PromptKey;
import com.chuseok22.elumserver.ai.core.SensitiveInfoCheckContent;
import com.chuseok22.elumserver.ai.core.SensitiveInfoCheckContent.Detection;
import com.chuseok22.elumserver.ai.core.SensitiveInfoCheckResult;
import com.chuseok22.elumserver.ai.infrastructure.client.LocalLlmChatRequest;
import com.chuseok22.elumserver.ai.infrastructure.client.LocalLlmChatResponse;
import com.chuseok22.elumserver.ai.infrastructure.client.LocalLlmClient;
import com.chuseok22.elumserver.common.infrastructure.exception.CustomException;
import com.chuseok22.elumserver.common.infrastructure.exception.ErrorCode;
import com.chuseok22.elumserver.common.infrastructure.properties.LocalLlmProperties;
import com.fasterxml.jackson.core.JsonProcessingException;
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
      log.info("로컬 LLM 민감정보 검증 비활성화 상태, 원문 그대로 통과: text={}", text);
      return passThrough(text);
    }

    String systemPrompt = promptTemplateService.getContent(PromptKey.LOCAL_LLM_SENSITIVE_INFO_CHECK);
    try {
      SensitiveInfoCheckContent content = callAndParse(systemPrompt, text);
      SensitiveInfoCheckResult result = toResult(text, content);
      log.info(
        "로컬 LLM 민감정보 검증 완료: hasSensitiveInfo={}, categories={}, sanitizedText={}",
        result.hasSensitiveInfo(), result.categories(), result.sanitizedText()
      );
      return result;
    } catch (Exception e) {
      // 개발 중 원인 추적을 위해 검사 대상 원문과 전체 스택트레이스를 함께 로그로 남긴다
      // (운영 로그는 개발자만 조회 가능하다는 전제 하에 원문 로깅을 허용하기로 결정됨).
      log.warn("로컬 LLM 민감정보 검증 실패, fail-open으로 통과 처리함: text={}", text, e);
      return passThrough(text);
    }
  }

  // 관리자 테스트 전용: local-llm.enabled 플래그와 fail-open 정책을 모두 우회하고 로컬 LLM을
  // 항상 직접 호출한다. enabled=false 상태에서도 관리자가 실제 탐지 성능을 검증할 수 있어야
  // 하고, 실패 시에도 마스킹 없이 통과된 것처럼 감추지 않고 에러를 그대로 노출해야 하기 때문이다.
  public SensitiveInfoCheckResult checkForTest(String systemPrompt, String text) {
    try {
      SensitiveInfoCheckContent content = callAndParse(systemPrompt, text);
      return toResult(text, content);
    } catch (Exception e) {
      log.warn("[관리자 테스트] 로컬 LLM 민감정보 검증 실패: systemPrompt={}, text={}", systemPrompt, text, e);
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

    // detections 필드 자체가 없으면(null) 스키마 위반으로 간주한다. 빈 배열([])은
    // "민감정보 없음"이라는 정상 응답이므로 통과시킨다.
    if (content.detections() == null) {
      throw new IllegalStateException("로컬 LLM 응답이 JSON Schema를 따르지 않음");
    }

    return content;
  }

  // detections를 카테고리 요약과 마스킹된 텍스트로 변환한다. matchedText가 원문에 없으면
  // (모델이 값을 정규화했거나 실제로 존재하지 않는 값을 만들어낸 경우) 해당 항목만 조용히
  // 건너뛴다 — 전체 요청을 실패 처리하지 않는다.
  private SensitiveInfoCheckResult toResult(String originalText, SensitiveInfoCheckContent content) {
    List<Detection> detections = content.detections();

    List<String> categories = detections.stream()
      .map(Detection::category)
      .distinct()
      .toList();

    String sanitizedText = originalText;
    for (Detection detection : detections) {
      if (sanitizedText.contains(detection.matchedText())) {
        sanitizedText = sanitizedText.replace(detection.matchedText(), "<" + detection.category() + ">");
      }
    }

    return new SensitiveInfoCheckResult(true, !detections.isEmpty(), categories, sanitizedText);
  }

  private String wrapAsData(String text) throws JsonProcessingException {
    return objectMapper.writeValueAsString(Map.of("text", text));
  }

  // fail-open 시 마스킹 없이 원문을 그대로 sanitizedText로 반환한다 — 검증 실패를 이유로
  // 서비스를 막지 않되, 이 경우 마스킹 없이 원문이 그대로 다음 단계(외부 AI)로 전달된다.
  private SensitiveInfoCheckResult passThrough(String originalText) {
    return new SensitiveInfoCheckResult(false, false, List.of(), originalText);
  }

  private Map<String, Object> responseFormat() {
    return Map.of(
      "type", "object",
      "additionalProperties", false,
      "properties", Map.of(
        "detections", Map.of(
          "type", "array",
          "items", Map.of(
            "type", "object",
            "additionalProperties", false,
            "properties", Map.of(
              "category", Map.of(
                "type", "string",
                "enum", List.of("이름", "전화번호", "주소", "이메일", "주민등록번호", "계좌번호", "생년월일", "진단명")
              ),
              "matchedText", Map.of("type", "string", "minLength", 1)
            ),
            "required", List.of("category", "matchedText")
          )
        )
      ),
      "required", List.of("detections")
    );
  }
}
