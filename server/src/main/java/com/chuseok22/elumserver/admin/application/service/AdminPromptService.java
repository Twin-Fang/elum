package com.chuseok22.elumserver.admin.application.service;

import com.chuseok22.elumserver.admin.application.dto.response.PromptTestResponse;
import com.chuseok22.elumserver.ai.application.service.PromptTemplateService;
import com.chuseok22.elumserver.ai.application.service.SensitiveInfoGuardService;
import com.chuseok22.elumserver.ai.core.ImagePromptLanguage;
import com.chuseok22.elumserver.ai.core.ImageProvider;
import com.chuseok22.elumserver.ai.infrastructure.client.FluxImageClient;
import com.chuseok22.elumserver.ai.infrastructure.client.FluxPromptBuilder;
import com.chuseok22.elumserver.ai.infrastructure.client.ImageGenerationClient;
import com.chuseok22.elumserver.ai.core.PromptKey;
import com.chuseok22.elumserver.ai.core.RoutineQuestionDraft;
import com.chuseok22.elumserver.ai.core.RoutineStepDraft;
import com.chuseok22.elumserver.ai.core.SensitiveInfoCheckResult;
import com.chuseok22.elumserver.ai.core.GeneratedImage;
import com.chuseok22.elumserver.ai.infrastructure.client.ImageClientRouter;
import com.chuseok22.elumserver.ai.infrastructure.client.GeminiRoutineImagePromptBuilder;
import com.chuseok22.elumserver.ai.infrastructure.client.GeminiTextClient;
import com.chuseok22.elumserver.ai.infrastructure.client.TextClientRouter;
import com.chuseok22.elumserver.ai.infrastructure.entity.PromptTemplate;
import com.chuseok22.elumserver.ai.infrastructure.entity.PromptTemplateHistory;
import com.chuseok22.elumserver.common.infrastructure.exception.CustomException;
import com.chuseok22.elumserver.common.infrastructure.exception.ErrorCode;
import com.chuseok22.elumserver.member.infrastructure.entity.CharacterType;
import com.fasterxml.jackson.databind.ObjectMapper;
import java.util.Base64;
import java.util.List;
import java.util.Map;
import java.util.Set;
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
  private final TextClientRouter textClientRouter;
  private final ImageClientRouter imageClientRouter;
  private final GeminiRoutineImagePromptBuilder imagePromptBuilder;
  private final FluxImageClient fluxImageClient;
  private final FluxPromptBuilder fluxPromptBuilder;

  public List<PromptTemplate> getAll() {
    return promptTemplateService.getAll();
  }

  public PromptTemplate getTemplate(PromptKey key) {
    return promptTemplateService.getTemplate(key);
  }

  public List<PromptTemplateHistory> getHistory(PromptKey key) {
    return promptTemplateService.getHistory(key);
  }

  public void update(PromptKey key, String content) {
    promptTemplateService.update(key, content);
  }

  // 각 클라이언트의 실제 프롬프트 조립 메서드를 그대로 재사용한다 — preview와 실제 호출이
  // 항상 같은 결과를 내도록, <text> 태그나 JSON 래핑을 이 메서드가 직접 조립하지 않는다.
  public String preview(PromptKey key, String content, String sampleInput, CharacterType character) {
    return switch (key) {
      case LOCAL_LLM_SENSITIVE_INFO_CHECK ->
        "[System]\n" + content + "\n\n[User]\n" + sensitiveInfoGuardService.buildUserContent(sampleInput);
      case GEMINI_ROUTINE_CREATE_PREFIX -> "[System]\n" + content + "\n\n[User]\n"
        + geminiTextClient.buildCreateRoutineUserContent(sampleInput, null, Set.of(), List.of());
      case GEMINI_ROUTINE_QUESTION_PREFIX -> "[System]\n" + content + "\n\n[User]\n"
        + geminiTextClient.buildQuestionUserContent(sampleInput, null, Set.of());
      // 미리보기도 지금 고른 제공자 기준으로 만든다 — 참조 이미지를 보내는지에 따라
      // 실제 프롬프트가 달라지는데, 여기서 다르게 보이면 미리보기를 믿을 수 없다 (#269).
      case GEMINI_ROUTINE_IMAGE_PREFIX -> imagePromptBuilder.build(
        content, sampleInput, character,
        character != null && imageClientRouter.current().supportsCharacterReference(),
        ImagePromptLanguage.KO
      );
      case ROUTINE_IMAGE_PREFIX_EN -> imagePromptBuilder.build(
        content, sampleInput, character,
        character != null && imageClientRouter.current().supportsCharacterReference(),
        ImagePromptLanguage.EN
      );
      // FLUX 는 JSON 장면 정보 없이 짧은 영어 한 덩어리다. 샘플 입력은 영어 장면 한 줄로 받는다 (#373).
      case FLUX_ROUTINE_IMAGE_PREFIX -> fluxPromptBuilder.build(content, sampleInput, character);
      case FLUX_IMAGE_PROMPT_TRANSLATE -> "[System]\n" + content + "\n\n[User]\n"
        + geminiTextClient.buildTranslateUserContent(sampleInput);
    };
  }

  public PromptTestResponse test(PromptKey key, String content, String sampleInput, CharacterType characterType) {
    return switch (key) {
      case LOCAL_LLM_SENSITIVE_INFO_CHECK -> {
        SensitiveInfoCheckResult result = sensitiveInfoGuardService.checkForTest(content, sampleInput);
        yield new PromptTestResponse(result, null);
      }
      case GEMINI_ROUTINE_CREATE_PREFIX -> {
        RoutineStepDraft draft = testGeminiText(content, sampleInput);
        yield new PromptTestResponse(draft, null);
      }
      case GEMINI_ROUTINE_QUESTION_PREFIX -> {
        RoutineQuestionDraft draft = testGeminiQuestion(content, sampleInput);
        yield new PromptTestResponse(draft, null);
      }
      case GEMINI_ROUTINE_IMAGE_PREFIX -> {
        String dataUri = testGeminiImage(content, ImagePromptLanguage.KO, sampleInput, characterType);
        yield new PromptTestResponse(null, dataUri);
      }
      // 저장하기 전에 영어 지시문을 지금 제공자로 그려 볼 수 있어야 언어를 바꿀지 정할 수 있다 (#375).
      case ROUTINE_IMAGE_PREFIX_EN -> {
        String dataUri = testGeminiImage(content, ImagePromptLanguage.EN, sampleInput, characterType);
        yield new PromptTestResponse(null, dataUri);
      }
      // 지금 고른 제공자와 무관하게 FLUX 로 그린다 — 운영을 OPENAI 로 둔 채 지시문을 다듬을 수 있어야
      // 전환 여부를 정할 수 있다. 한 번에 $0.003 (#373).
      case FLUX_ROUTINE_IMAGE_PREFIX -> {
        String dataUri = testFluxImage(content, sampleInput, characterType);
        yield new PromptTestResponse(null, dataUri);
      }
      case FLUX_IMAGE_PROMPT_TRANSLATE -> {
        String line = testTranslate(content, sampleInput);
        yield new PromptTestResponse(Map.of("imagePromptEn", line), null);
      }
    };
  }

  private RoutineStepDraft testGeminiText(String systemPrompt, String sampleInput) {
    try {
      String json = textClientRouter.current().generateRoutineJsonForTest(systemPrompt, sampleInput);
      return objectMapper.readValue(json, RoutineStepDraft.class);
    } catch (Exception e) {
      log.warn("[관리자 테스트] 텍스트 생성 실패: systemPrompt={}, sampleInput={}", systemPrompt, sampleInput, e);
      throw new CustomException(ErrorCode.PROMPT_TEST_GEMINI_TEXT_FAILED);
    }
  }

  private RoutineQuestionDraft testGeminiQuestion(String systemPrompt, String sampleInput) {
    try {
      String json = textClientRouter.current().generateQuestionJsonForTest(systemPrompt, sampleInput);
      return objectMapper.readValue(json, RoutineQuestionDraft.class);
    } catch (Exception e) {
      log.warn("[관리자 테스트] 질문 생성 실패: systemPrompt={}, sampleInput={}", systemPrompt, sampleInput, e);
      throw new CustomException(ErrorCode.PROMPT_TEST_GEMINI_TEXT_FAILED);
    }
  }

  private String testFluxImage(String prefix, String sampleScene, CharacterType characterType) {
    try {
      return toDataUri(fluxImageClient.generateForTest(prefix, sampleScene, characterType));
    } catch (Exception e) {
      log.warn("[관리자 테스트] FLUX 이미지 생성 실패: prefix={}, sampleInput={}", prefix, sampleScene, e);
      throw new CustomException(ErrorCode.PROMPT_TEST_GEMINI_IMAGE_FAILED);
    }
  }

  private String testTranslate(String systemPrompt, String sampleInput) {
    try {
      return geminiTextClient.translateImagePromptForTest(systemPrompt, sampleInput);
    } catch (Exception e) {
      log.warn("[관리자 테스트] 그림 문장 번역 실패: sampleInput={}", sampleInput, e);
      throw new CustomException(ErrorCode.PROMPT_TEST_GEMINI_TEXT_FAILED);
    }
  }

  private String toDataUri(GeneratedImage image) {
    return "data:image/" + image.extension() + ";base64," + Base64.getEncoder().encodeToString(image.bytes());
  }

  /**
   * 한국어·영어 그림 지시문을 시험할 제공자.
   *
   * <p>FLUX 를 골라 두었으면 이 지시문들은 FLUX 가 아니라 <b>OpenAI fallback</b> 이 쓴다. FLUX 로
   * 그리면 한국어 지시문을 받아 사람을 그린다(#373). 그래서 그때는 OpenAI 로 시험한다.
   */
  private ImageGenerationClient promptTestImageClient() {
    ImageGenerationClient current = imageClientRouter.current();
    if (current.provider() != ImageProvider.FLUX) {
      return current;
    }
    return imageClientRouter.of(ImageProvider.OPENAI)
      .filter(ImageGenerationClient::available)
      .orElse(current);
  }

  private String testGeminiImage(
    String prefix, ImagePromptLanguage language, String sampleInput, CharacterType characterType
  ) {
    try {
      GeneratedImage image =
        promptTestImageClient().generateImageForTest(prefix, language, sampleInput, characterType);
      String base64 = Base64.getEncoder().encodeToString(image.bytes());
      return "data:image/" + image.extension() + ";base64," + base64;
    } catch (Exception e) {
      log.warn("[관리자 테스트] 이미지 생성 실패: prefix={}, sampleInput={}", prefix, sampleInput, e);
      throw new CustomException(ErrorCode.PROMPT_TEST_GEMINI_IMAGE_FAILED);
    }
  }
}
