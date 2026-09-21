package com.chuseok22.elumserver.ai.infrastructure.client;

import com.chuseok22.elumserver.ai.application.service.AiCallLogService;
import com.chuseok22.elumserver.ai.application.service.PromptTemplateService;
import com.chuseok22.elumserver.ai.core.AiCallType;
import com.chuseok22.elumserver.ai.core.GeneratedImage;
import com.chuseok22.elumserver.ai.core.ImageProvider;
import com.chuseok22.elumserver.ai.core.PromptKey;
import com.chuseok22.elumserver.member.infrastructure.entity.CharacterType;
import com.chuseok22.elumserver.systemconfig.application.service.SystemConfigService;
import com.chuseok22.elumserver.systemconfig.core.ConfigKey;
import java.time.Duration;
import java.util.Base64;
import java.util.List;
import java.util.Map;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.http.client.SimpleClientHttpRequestFactory;
import org.springframework.stereotype.Component;
import org.springframework.web.client.RestClient;

/**
 * OpenAI 이미지 생성.
 *
 * <p>Gemini 대비 장당 단가가 훨씬 싸다. 카드 삽화가 AI 비용의 99%를 차지하므로
 * 여기를 바꾸는 것만으로 원가가 크게 내려간다.
 *
 * <p><b>다만 캐릭터 일관성을 지키지 못한다.</b> 참조 이미지를 함께 보내려면 편집
 * 계열 API를 따로 써야 하는데 지금은 그 경로를 붙이지 않았다. 캐릭터가 단계마다
 * 달라지면 일과 카드가 한 이야기로 읽히지 않으므로, 관리자 화면이 이 사실을 경고한다.
 */
@Slf4j
@Component
@RequiredArgsConstructor
public class OpenAiImageClient implements ImageGenerationClient {

  private static final String BASE_URL = "https://api.openai.com";
  // 카드 이미지 영역이 약 1.19:1이라 정사각형이 가장 가깝다. 가로형(1536x1024)은
  // 1.5:1이라 오히려 더 많이 잘린다.
  private static final String IMAGE_SIZE = "1024x1024";

  private final PromptTemplateService promptTemplateService;
  private final GeminiRoutineImagePromptBuilder imagePromptBuilder;
  private final SystemConfigService systemConfigService;
  private final AiCallLogService aiCallLogService;

  private final RestClient restClient = buildRestClient();

  @Override
  public ImageProvider provider() {
    return ImageProvider.OPENAI;
  }

  @Override
  public boolean available() {
    return systemConfigService.hasSecret(ConfigKey.OPENAI_API_KEY);
  }

  @Override
  public boolean supportsCharacterReference() {
    return false;
  }

  @Override
  public GeneratedImage generateImage(String stepDescription, CharacterType characterType) {
    String prefix = promptTemplateService.getContent(PromptKey.GEMINI_ROUTINE_IMAGE_PREFIX);
    return call(prefix, stepDescription, characterType);
  }

  @Override
  public GeneratedImage generateImageForTest(String prefix, String sampleInput, CharacterType characterType) {
    return call(prefix, sampleInput, characterType);
  }

  private GeneratedImage call(String prefix, String stepDescription, CharacterType characterType) {
    // 프롬프트는 Gemini와 같은 것을 쓴다. 제공자를 바꿨다고 그림의 결이 달라지면
    // 비교가 성립하지 않는다.
    String prompt = imagePromptBuilder.build(prefix, stepDescription, characterType, false);
    String model = systemConfigService.getString(ConfigKey.OPENAI_IMAGE_MODEL);
    String quality = systemConfigService.getString(ConfigKey.OPENAI_IMAGE_QUALITY);
    String apiKey = systemConfigService.getSecret(ConfigKey.OPENAI_API_KEY);

    long startedAt = System.currentTimeMillis();
    log.info("OpenAI 이미지 생성 호출 시작: model={}, quality={}, characterType={}",
      model, quality, characterType);
    try {
      OpenAiImageResponse response = restClient.post()
        .uri("/v1/images/generations")
        .header("Authorization", "Bearer " + apiKey)
        .body(Map.of(
          "model", model,
          "prompt", prompt,
          "quality", quality,
          "size", IMAGE_SIZE,
          "n", 1
        ))
        .retrieve()
        .body(OpenAiImageResponse.class);

      GeneratedImage image = extractImage(response);
      aiCallLogService.recordSuccess(
        AiCallType.OPENAI_IMAGE, model, System.currentTimeMillis() - startedAt, null);
      log.info("OpenAI 이미지 생성 호출 완료: model={}, elapsedMs={}",
        model, System.currentTimeMillis() - startedAt);
      return image;
    } catch (Exception e) {
      long elapsedMs = System.currentTimeMillis() - startedAt;
      log.warn("OpenAI 이미지 생성 호출 실패: model={}, elapsedMs={}", model, elapsedMs, e);
      aiCallLogService.recordFailure(AiCallType.OPENAI_IMAGE, model, elapsedMs, e.getMessage());
      throw e;
    }
  }

  // GPT 이미지 모델은 언제나 base64로 돌려준다(response_format 파라미터를 받지 않는다).
  private GeneratedImage extractImage(OpenAiImageResponse response) {
    if (response == null || response.data() == null || response.data().isEmpty()) {
      throw new IllegalStateException("OpenAI 응답에 이미지가 없음");
    }
    String base64 = response.data().get(0).b64Json();
    if (base64 == null || base64.isBlank()) {
      throw new IllegalStateException("OpenAI 응답에 이미지 데이터가 없음");
    }
    return new GeneratedImage(Base64.getDecoder().decode(base64), "png");
  }

  // 이미지 생성은 수십 초가 걸린다. 읽기 제한을 넉넉히 두되 무한 대기는 막는다.
  private static RestClient buildRestClient() {
    SimpleClientHttpRequestFactory factory = new SimpleClientHttpRequestFactory();
    factory.setConnectTimeout(Duration.ofSeconds(10));
    factory.setReadTimeout(Duration.ofSeconds(120));
    return RestClient.builder().baseUrl(BASE_URL).requestFactory(factory).build();
  }

  /// 응답에서 쓰는 것만 담는다. 모르는 필드는 무시된다.
  record OpenAiImageResponse(List<OpenAiImageData> data) {

    record OpenAiImageData(
      @com.fasterxml.jackson.annotation.JsonProperty("b64_json") String b64Json
    ) {

    }
  }
}
