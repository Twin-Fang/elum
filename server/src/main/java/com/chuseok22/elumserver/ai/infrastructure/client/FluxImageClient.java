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
import java.util.List;
import java.util.Map;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.http.client.SimpleClientHttpRequestFactory;
import org.springframework.stereotype.Component;
import org.springframework.web.client.RestClient;

/**
 * FLUX 이미지 생성 (fal.ai).
 *
 * <p>Gemini보다 훨씬 싸다. <b>캐릭터 일관성은 지키지 못한다</b> — 참조 이미지를 받는
 * 경로가 아니라 글만 보고 그린다. 단계마다 캐릭터가 달라지므로 관리자 화면이 경고한다.
 *
 * <p>다른 제공자와 달리 <b>이미지를 바로 주지 않고 주소를 준다.</b> 그래서 한 번 더
 * 받아와야 한다. 그 사이에 주소가 죽거나 느리면 생성 자체가 실패로 떨어진다.
 */
@Slf4j
@Component
@RequiredArgsConstructor
public class FluxImageClient implements ImageGenerationClient {

  private static final String BASE_URL = "https://fal.run";
  // 카드 이미지 영역이 약 1.19:1이라 4:3(1.33:1)이 가장 가깝다.
  private static final String IMAGE_SIZE = "landscape_4_3";
  private static final int INFERENCE_STEPS = 4;

  private final PromptTemplateService promptTemplateService;
  private final GeminiRoutineImagePromptBuilder imagePromptBuilder;
  private final SystemConfigService systemConfigService;
  private final AiCallLogService aiCallLogService;

  private final RestClient restClient = buildRestClient(BASE_URL);
  /// 결과 이미지를 받아오는 용도. 주소가 fal.ai 바깥일 수 있어 baseUrl을 두지 않는다.
  private final RestClient downloadClient = buildRestClient(null);

  @Override
  public ImageProvider provider() {
    return ImageProvider.FLUX;
  }

  @Override
  public boolean available() {
    return systemConfigService.hasSecret(ConfigKey.FLUX_API_KEY);
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
    String prompt = imagePromptBuilder.build(prefix, stepDescription, characterType);
    String model = systemConfigService.getString(ConfigKey.FLUX_IMAGE_MODEL);
    String apiKey = systemConfigService.getSecret(ConfigKey.FLUX_API_KEY);

    long startedAt = System.currentTimeMillis();
    log.info("FLUX 이미지 생성 호출 시작: model={}, characterType={}", model, characterType);
    try {
      FluxImageResponse response = restClient.post()
        .uri("/" + model)
        .header("Authorization", "Key " + apiKey)
        .body(Map.of(
          "prompt", prompt,
          "image_size", IMAGE_SIZE,
          "num_inference_steps", INFERENCE_STEPS,
          "num_images", 1
        ))
        .retrieve()
        .body(FluxImageResponse.class);

      GeneratedImage image = download(response);
      aiCallLogService.recordSuccess(
        AiCallType.FLUX_IMAGE, model, System.currentTimeMillis() - startedAt, null);
      log.info("FLUX 이미지 생성 호출 완료: model={}, elapsedMs={}",
        model, System.currentTimeMillis() - startedAt);
      return image;
    } catch (Exception e) {
      long elapsedMs = System.currentTimeMillis() - startedAt;
      log.warn("FLUX 이미지 생성 호출 실패: model={}, elapsedMs={}", model, elapsedMs, e);
      aiCallLogService.recordFailure(AiCallType.FLUX_IMAGE, model, elapsedMs, e.getMessage());
      throw e;
    }
  }

  private GeneratedImage download(FluxImageResponse response) {
    if (response == null || response.images() == null || response.images().isEmpty()) {
      throw new IllegalStateException("FLUX 응답에 이미지가 없음");
    }
    FluxImageResponse.FluxImage first = response.images().get(0);
    if (first.url() == null || first.url().isBlank()) {
      throw new IllegalStateException("FLUX 응답에 이미지 주소가 없음");
    }
    byte[] bytes = downloadClient.get().uri(first.url()).retrieve().body(byte[].class);
    if (bytes == null || bytes.length == 0) {
      throw new IllegalStateException("FLUX 이미지를 받아오지 못함");
    }
    return new GeneratedImage(bytes, extensionOf(first.contentType()));
  }

  private String extensionOf(String contentType) {
    if (contentType == null) {
      return "png";
    }
    return switch (contentType) {
      case "image/jpeg" -> "jpg";
      case "image/webp" -> "webp";
      default -> "png";
    };
  }

  private static RestClient buildRestClient(String baseUrl) {
    SimpleClientHttpRequestFactory factory = new SimpleClientHttpRequestFactory();
    factory.setConnectTimeout(Duration.ofSeconds(10));
    factory.setReadTimeout(Duration.ofSeconds(120));
    RestClient.Builder builder = RestClient.builder().requestFactory(factory);
    return baseUrl == null ? builder.build() : builder.baseUrl(baseUrl).build();
  }

  record FluxImageResponse(List<FluxImage> images) {

    record FluxImage(
      String url,
      @com.fasterxml.jackson.annotation.JsonProperty("content_type") String contentType
    ) {

    }
  }
}
