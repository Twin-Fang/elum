package com.chuseok22.elumserver.ai.infrastructure.client;

import com.chuseok22.elumserver.ai.application.service.AiCallLogService;
import com.chuseok22.elumserver.ai.application.service.PromptTemplateService;
import com.chuseok22.elumserver.ai.core.AiCallType;
import com.chuseok22.elumserver.ai.core.GeneratedImage;
import com.chuseok22.elumserver.ai.core.ImagePromptLanguage;
import com.chuseok22.elumserver.ai.core.ImageProvider;
import com.chuseok22.elumserver.ai.core.PromptKey;
import com.chuseok22.elumserver.member.infrastructure.entity.CharacterType;
import com.chuseok22.elumserver.systemconfig.application.service.SystemConfigService;
import com.chuseok22.elumserver.systemconfig.core.ConfigKey;
import java.time.Duration;
import java.util.LinkedHashMap;
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
 * <p>Gemini보다 훨씬 싸다. <b>참조 그림을 받지 못한다</b> — 글만 보고 그린다. 그래서 한 일과의
 * 카드들을 같은 seed 로 그려 캐릭터를 맞춘다 (#373 2차 시험에서 확인).
 *
 * <p><b>영어 장면이 있어야 부를 수 있다.</b> schnell 은 한국어를 거의 못 알아들어 사람을 그렸고,
 * 긴 지시문은 그림 속 글자로 찍었다. 그래서 다른 제공자와 달리 한국어 카드 설명을 받는
 * {@link #generateImage}는 쓰지 않고, {@code CardImageGenerator} 가 영어 장면을 마련해
 * {@link #generate} 를 부른다. 실패하면 그 카드만 OpenAI 로 돌리는 것도 그쪽이 한다.
 *
 * <p>다른 제공자와 달리 <b>이미지를 바로 주지 않고 주소를 준다.</b> 그래서 한 번 더
 * 받아와야 한다. 그 사이에 주소가 죽거나 느리면 생성 자체가 실패로 떨어진다.
 *
 * <p><b>품질 실패는 잡지 못한다.</b> 동작이 안 그려지거나 글자가 찍혀도 API 는 성공으로 끝난다
 * (#373 원인 분석). 에러·타임아웃·잔액 소진만 실패로 떨어진다.
 */
@Slf4j
@Component
@RequiredArgsConstructor
public class FluxImageClient implements ImageGenerationClient {

  private static final String BASE_URL = "https://fal.run";
  // fal 은 한 장을 최소 1MP 로 청구한다 — 작게 그려도 싸지지 않는다(#373 대시보드 실측).
  // 1MP 안에서 카드 그림칸(313×264, 약 1.19:1) 비율로 가장 크게: 1024×864 = 0.88MP.
  static final int IMAGE_WIDTH = 1024;
  static final int IMAGE_HEIGHT = 864;
  // schnell 은 4단계로 줄인 모델이다. 8단계로 올려도 동작이 나아지지 않았다(#373 3차).
  private static final int INFERENCE_STEPS = 4;

  private final PromptTemplateService promptTemplateService;
  private final FluxPromptBuilder fluxPromptBuilder;
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

  /**
   * 한국어 카드 설명으로는 그리지 않는다.
   *
   * <p>그대로 보내면 카드에 사람이 그려진다(#373 1차). 조용히 틀린 그림을 내느니 실패시켜
   * 부르는 쪽이 기본 그림으로 덮게 한다. 정상 경로는 {@link #generate} 다.
   */
  @Override
  public GeneratedImage generateImage(String stepDescription, CharacterType characterType) {
    throw new IllegalStateException("FLUX 는 영어 장면이 필요하다 — CardImageGenerator 를 거쳐 부른다");
  }

  /// 관리자 시험: 언어와 무관하게 FLUX 지시문 + 샘플 입력(영어 장면 한 줄)으로 그린다.
  @Override
  public GeneratedImage generateImageForTest(
    String prefix, ImagePromptLanguage language, String sampleInput, CharacterType characterType
  ) {
    return generateForTest(prefix, sampleInput, characterType);
  }

  /**
   * @param sceneEn 카드의 영어 장면 한 줄("The character …")
   * @param seed    일과마다 고정한 seed. null 이면 fal 이 고른다
   */
  public GeneratedImage generate(String sceneEn, CharacterType characterType, Integer seed) {
    String prefix = promptTemplateService.getContent(PromptKey.FLUX_ROUTINE_IMAGE_PREFIX);
    return call(fluxPromptBuilder.build(prefix, sceneEn, characterType), seed);
  }

  /// 관리자 시험 전용: 저장된 지시문 대신 넘겨받은 것을 쓴다. seed 는 두지 않는다.
  public GeneratedImage generateForTest(String prefix, String sceneEn, CharacterType characterType) {
    return call(fluxPromptBuilder.build(prefix, sceneEn, characterType), null);
  }

  /// fal 에 보내는 본문. 크기·단계·seed 가 곧 돈과 품질이라 테스트가 직접 본다.
  Map<String, Object> requestBody(String prompt, Integer seed) {
    Map<String, Object> body = new LinkedHashMap<>();
    body.put("prompt", prompt);
    body.put("image_size", Map.of("width", IMAGE_WIDTH, "height", IMAGE_HEIGHT));
    body.put("num_inference_steps", INFERENCE_STEPS);
    body.put("num_images", 1);
    if (seed != null) {
      body.put("seed", seed);
    }
    return body;
  }

  private GeneratedImage call(String prompt, Integer seed) {
    String model = systemConfigService.getString(ConfigKey.FLUX_IMAGE_MODEL);
    String apiKey = systemConfigService.getSecret(ConfigKey.FLUX_API_KEY);

    long startedAt = System.currentTimeMillis();
    // 프롬프트는 카드 한 장의 영어 장면뿐이라 남긴다 — 그림이 틀렸을 때 무엇을 보냈는지 봐야 한다.
    log.info("FLUX 이미지 생성 호출 시작: model={}, seed={}, prompt={}", model, seed, prompt);
    try {
      FluxImageResponse response = restClient.post()
        .uri("/" + model)
        .header("Authorization", "Key " + apiKey)
        .body(requestBody(prompt, seed))
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
