package com.chuseok22.elumserver.admin.application.service;

import com.chuseok22.elumserver.admin.application.dto.response.PromptTestResponse;
import com.chuseok22.elumserver.ai.application.service.PromptTemplateService;
import com.chuseok22.elumserver.ai.application.service.SensitiveInfoGuardService;
import com.chuseok22.elumserver.ai.core.PromptKey;
import com.chuseok22.elumserver.ai.core.RoutineQuestionDraft;
import com.chuseok22.elumserver.ai.core.RoutineStepDraft;
import com.chuseok22.elumserver.ai.core.SensitiveInfoCheckResult;
import com.chuseok22.elumserver.ai.infrastructure.client.GeminiGenerateContentResponse;
import com.chuseok22.elumserver.ai.infrastructure.client.GeminiImageClient;
import com.chuseok22.elumserver.ai.infrastructure.client.GeminiTextClient;
import com.chuseok22.elumserver.ai.infrastructure.entity.PromptTemplate;
import com.chuseok22.elumserver.common.infrastructure.exception.CustomException;
import com.chuseok22.elumserver.common.infrastructure.exception.ErrorCode;
import com.fasterxml.jackson.databind.ObjectMapper;
import java.util.Base64;
import java.util.List;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Service;

@Slf4j
@Service
@RequiredArgsConstructor
public class AdminPromptService {

  // Spring Boot 4.1은 Jackson 3 기반이라 Jackson 2 ObjectMapper 빈이 자동 구성되지 않으므로
  // SensitiveInfoGuardService/RoutineAiPipeline과 동일하게 직접 생성해서 쓴다.
  private final ObjectMapper objectMapper = new ObjectMapper();

  private final PromptTemplateService promptTemplateService;
  private final SensitiveInfoGuardService sensitiveInfoGuardService;
  private final GeminiTextClient geminiTextClient;
  private final GeminiImageClient geminiImageClient;

  public List<PromptTemplate> getAll() {
    return promptTemplateService.getAll();
  }

  public void update(PromptKey key, String content) {
    promptTemplateService.update(key, content);
  }

  // 각 클라이언트의 실제 프롬프트 조립 방식을 그대로 재현한다:
  // - LOCAL_LLM/텍스트/질문 생성: <text> 태그로 래핑
  // - 이미지: prefix + 설명을 그대로 이어붙임(래핑 없음, GeminiImageClient와 동일)
  public String preview(PromptKey key, String content, String sampleInput) {
    return switch (key) {
      case LOCAL_LLM_SENSITIVE_INFO_CHECK, GEMINI_ROUTINE_TEXT_PREFIX, GEMINI_ROUTINE_QUESTION_PREFIX ->
        "[System]\n" + content + "\n\n[User]\n<text>" + sampleInput + "</text>";
      case GEMINI_ROUTINE_IMAGE_PREFIX -> content + sampleInput;
    };
  }

  public PromptTestResponse test(PromptKey key, String content, String sampleInput) {
    return switch (key) {
      case LOCAL_LLM_SENSITIVE_INFO_CHECK -> {
        SensitiveInfoCheckResult result = sensitiveInfoGuardService.checkForTest(content, sampleInput);
        yield new PromptTestResponse(result, null);
      }
      case GEMINI_ROUTINE_TEXT_PREFIX -> {
        RoutineStepDraft draft = testGeminiText(content, sampleInput);
        yield new PromptTestResponse(draft, null);
      }
      case GEMINI_ROUTINE_QUESTION_PREFIX -> {
        RoutineQuestionDraft draft = testGeminiQuestion(content, sampleInput);
        yield new PromptTestResponse(draft, null);
      }
      case GEMINI_ROUTINE_IMAGE_PREFIX -> {
        String dataUri = testGeminiImage(content, sampleInput);
        yield new PromptTestResponse(null, dataUri);
      }
    };
  }

  private RoutineStepDraft testGeminiText(String systemPrompt, String sampleInput) {
    try {
      GeminiGenerateContentResponse response = geminiTextClient.generateForTest(systemPrompt, sampleInput);
      String json = response.candidates().get(0).content().parts().get(0).text();
      return objectMapper.readValue(json, RoutineStepDraft.class);
    } catch (Exception e) {
      log.warn("[관리자 테스트] Gemini 텍스트 생성 실패: {}", e.getClass().getSimpleName());
      throw new CustomException(ErrorCode.PROMPT_TEST_GEMINI_TEXT_FAILED);
    }
  }

  private RoutineQuestionDraft testGeminiQuestion(String systemPrompt, String sampleInput) {
    try {
      GeminiGenerateContentResponse response = geminiTextClient.generateQuestionForTest(systemPrompt, sampleInput);
      String json = response.candidates().get(0).content().parts().get(0).text();
      return objectMapper.readValue(json, RoutineQuestionDraft.class);
    } catch (Exception e) {
      log.warn("[관리자 테스트] Gemini 질문 생성 실패: {}", e.getClass().getSimpleName());
      throw new CustomException(ErrorCode.PROMPT_TEST_GEMINI_TEXT_FAILED);
    }
  }

  private String testGeminiImage(String prefix, String sampleInput) {
    try {
      GeminiImageClient.GeneratedImage image = geminiImageClient.generateImageForTest(prefix, sampleInput);
      String base64 = Base64.getEncoder().encodeToString(image.bytes());
      return "data:image/" + image.extension() + ";base64," + base64;
    } catch (Exception e) {
      log.warn("[관리자 테스트] Gemini 이미지 생성 실패: {}", e.getClass().getSimpleName());
      throw new CustomException(ErrorCode.PROMPT_TEST_GEMINI_IMAGE_FAILED);
    }
  }
}
