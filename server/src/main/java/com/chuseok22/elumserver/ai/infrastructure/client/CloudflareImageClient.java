package com.chuseok22.elumserver.ai.infrastructure.client;

import com.chuseok22.elumserver.ai.application.service.AiCallLogService;
import com.chuseok22.elumserver.ai.application.service.PromptTemplateService;
import com.chuseok22.elumserver.ai.core.AiCallType;
import com.chuseok22.elumserver.ai.core.CardImageSubject;
import com.chuseok22.elumserver.ai.core.GeneratedImage;
import com.chuseok22.elumserver.ai.core.ImagePromptLanguage;
import com.chuseok22.elumserver.ai.core.ImageProvider;
import com.chuseok22.elumserver.ai.core.PromptKey;
import com.chuseok22.elumserver.common.infrastructure.logging.LogTextLength;
import com.chuseok22.elumserver.member.infrastructure.entity.CharacterType;
import com.chuseok22.elumserver.systemconfig.application.service.SystemConfigService;
import com.chuseok22.elumserver.systemconfig.core.ConfigKey;
import java.time.Clock;
import java.time.Instant;
import java.time.LocalDate;
import java.time.ZoneOffset;
import java.util.Base64;
import java.util.regex.Matcher;
import java.util.regex.Pattern;
import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.http.MediaType;
import org.springframework.stereotype.Component;
import org.springframework.util.LinkedMultiValueMap;
import org.springframework.util.MultiValueMap;
import org.springframework.web.client.RestClient;
import org.springframework.web.client.RestClientResponseException;

/**
 * Cloudflare Workers AI 카드 그림 (klein-4b): 만화는 프로필 캐릭터 대신 카드 그림 인물, 실사는 실사 지시문
 * 하루 무료 한도 초과(4006)를 받으면 다음 00:00 UTC 까지 호출 없이 실패 > CardImageGenerator 가 OpenAI 로
 */
@Slf4j
@Component
public class CloudflareImageClient implements EnglishSceneImageClient {

  private static final String BASE_URL = "https://api.cloudflare.com/client/v4";
  // 카드 칸 비율(313x230 = 1.36). klein-4b 는 크기와 무관하게 1장 104.2 neurons 라 작게 그린다 (#1257 실측)
  static final int IMAGE_WIDTH = 512;
  static final int IMAGE_HEIGHT = 376;
  // Cloudflare 오류 코드: 하루 무료 사용량(10,000 neurons) 소진
  static final String DAILY_FREE_ALLOCATION_USED_UP = "4006";
  private static final Pattern ERROR_CODE = Pattern.compile("\"code\"\\s*:\\s*(\\d+)");

  private final PromptTemplateService promptTemplateService;
  private final FluxPromptBuilder fluxPromptBuilder;
  private final SystemConfigService systemConfigService;
  private final AiCallLogService aiCallLogService;
  private final RestClient restClient;
  private final Clock clock;

  // 무료 한도 소진 후 다시 부를 시각 (서버 메모리, 재시작하면 한 번 다시 시도)
  private volatile Instant quotaExhaustedUntil = Instant.EPOCH;

  @Autowired
  public CloudflareImageClient(PromptTemplateService promptTemplateService, FluxPromptBuilder fluxPromptBuilder,
    SystemConfigService systemConfigService, AiCallLogService aiCallLogService,
    AiRestClientFactory restClientFactory) {
    this(promptTemplateService, fluxPromptBuilder, systemConfigService, aiCallLogService,
      restClientFactory.create(BASE_URL), Clock.systemUTC());
  }

  CloudflareImageClient(PromptTemplateService promptTemplateService, FluxPromptBuilder fluxPromptBuilder,
    SystemConfigService systemConfigService, AiCallLogService aiCallLogService, RestClient restClient, Clock clock) {
    this.promptTemplateService = promptTemplateService;
    this.fluxPromptBuilder = fluxPromptBuilder;
    this.systemConfigService = systemConfigService;
    this.aiCallLogService = aiCallLogService;
    this.restClient = restClient;
    this.clock = clock;
  }

  @Override
  public ImageProvider provider() {
    return ImageProvider.CLOUDFLARE;
  }

  /// 토큰·계정 ID·모델이 모두 있어야 부를 수 있다
  @Override
  public boolean available() {
    return systemConfigService.hasSecret(ConfigKey.CLOUDFLARE_API_TOKEN)
      && !systemConfigService.getString(ConfigKey.CLOUDFLARE_ACCOUNT_ID).isBlank()
      && !systemConfigService.getString(ConfigKey.CLOUDFLARE_IMAGE_MODEL).isBlank();
  }

  @Override
  public boolean isTemporarilySkipped() {
    return isQuotaExhausted();
  }

  @Override
  public boolean supportsCharacterReference() {
    return false;
  }

  @Override
  public boolean shouldDropProfileCharacter() {
    return true;
  }

  /// 한국어 설명으로는 그리지 않는다 (사람·글자가 그려짐) > 영어 장면 경로로만
  @Override
  public GeneratedImage generateImage(String stepDescription, CharacterType characterType) {
    throw new IllegalStateException("Cloudflare 는 영어 장면이 필요하다 — CardImageGenerator 를 거쳐 부른다");
  }

  @Override
  public GeneratedImage generateImageForTest(
    String prefix, ImagePromptLanguage language, String sampleInput, CharacterType characterType
  ) {
    return generateForTest(prefix, sampleInput, characterType);
  }

  @Override
  public GeneratedImage generate(String sceneEn, CharacterType characterType, Integer seed) {
    return call(buildCartoonPrompt(promptTemplateService.getContent(PromptKey.FLUX_ROUTINE_IMAGE_PREFIX), sceneEn,
      characterType), seed);
  }

  @Override
  public GeneratedImage generateRealistic(String sceneEn, Integer seed) {
    String prefix = promptTemplateService.getContent(PromptKey.REALISTIC_ROUTINE_IMAGE_PREFIX);
    return call(fluxPromptBuilder.buildRealistic(prefix, sceneEn), seed);
  }

  @Override
  public GeneratedImage generateForTest(String prefix, String sceneEn, CharacterType characterType) {
    return call(buildCartoonPrompt(prefix, sceneEn, characterType), null);
  }

  /// 관리자 시험: 생김새 지시문을 저장 전 값으로 그려 본다 (seed 없음)
  public GeneratedImage generateWithAppearanceForTest(String prefix, String appearance, String sceneEn) {
    return call(fluxPromptBuilder.build(prefix, sceneEn, appearance,
      CardImageSubject.CHILD.getSubjectEn()), null);
  }

  /// 화풍 + 카드 그림 인물 생김새 + 장면 (프로필 캐릭터 생김새는 쓰지 않음)
  public String buildCartoonPrompt(String prefix, String sceneEn, CharacterType characterType) {
    CardImageSubject subject = CardImageSubject.forProfileCharacter(characterType);
    String appearance = promptTemplateService.getContent(subject.getAppearanceKey());
    return fluxPromptBuilder.build(prefix, sceneEn, appearance, subject.getSubjectEn());
  }

  /// multipart 본문 (크기·seed 가 곧 품질·재현성이라 테스트가 직접 본다)
  MultiValueMap<String, Object> requestParts(String prompt, Integer seed) {
    MultiValueMap<String, Object> parts = new LinkedMultiValueMap<>();
    parts.add("prompt", prompt);
    parts.add("width", String.valueOf(IMAGE_WIDTH));
    parts.add("height", String.valueOf(IMAGE_HEIGHT));
    if (seed != null) {
      parts.add("seed", String.valueOf(seed));
    }
    return parts;
  }

  boolean isQuotaExhausted() {
    return clock.instant().isBefore(quotaExhaustedUntil);
  }

  /// 한도 소진 표시: 다음 00:00 UTC 까지
  void markQuotaExhausted() {
    LocalDate today = LocalDate.ofInstant(clock.instant(), ZoneOffset.UTC);
    quotaExhaustedUntil = today.plusDays(1).atStartOfDay(ZoneOffset.UTC).toInstant();
  }

  private GeneratedImage call(String prompt, Integer seed) {
    // 한도 소진 날은 호출 없이 실패 (기록도 남기지 않음 — 카드마다 쌓이지 않게)
    if (isQuotaExhausted()) {
      throw new IllegalStateException("cloudflare daily free allocation used up until " + quotaExhaustedUntil);
    }
    String model = systemConfigService.getString(ConfigKey.CLOUDFLARE_IMAGE_MODEL);
    String accountId = systemConfigService.getString(ConfigKey.CLOUDFLARE_ACCOUNT_ID);
    String token = systemConfigService.getSecret(ConfigKey.CLOUDFLARE_API_TOKEN);

    long startedAt = clock.millis();
    log.info("[cloudflare image] request : model={}, seed={}, promptLength={}", model, seed, LogTextLength.of(prompt));
    try {
      CloudflareImageResponse response = restClient.post()
        // 모델 ID 의 '/'·'@' 가 URI 변수 인코딩으로 깨지지 않게 경로를 그대로 붙인다
        .uri("/accounts/" + accountId.trim() + "/ai/run/" + model.trim())
        .header("Authorization", "Bearer " + token)
        .contentType(MediaType.MULTIPART_FORM_DATA)
        .body(requestParts(prompt, seed))
        .retrieve()
        .body(CloudflareImageResponse.class);
      GeneratedImage image = toImage(response);
      long elapsedMs = clock.millis() - startedAt;
      aiCallLogService.recordSuccess(AiCallType.CLOUDFLARE_IMAGE, model, elapsedMs, null);
      log.info("[cloudflare image] done : model={}, elapsedMs={}", model, elapsedMs);
      return image;
    } catch (RestClientResponseException e) {
      String failure = failureSummary(e);
      if (DAILY_FREE_ALLOCATION_USED_UP.equals(errorCodeOf(e.getResponseBodyAsString()))) {
        markQuotaExhausted();
        log.warn("[cloudflare image] rejected {} : daily free allocation used up, skip until {}",
          e.getStatusCode().value(), quotaExhaustedUntil);
      } else {
        log.warn("[cloudflare image] rejected {} : {}", e.getStatusCode().value(), failure);
      }
      aiCallLogService.recordFailure(AiCallType.CLOUDFLARE_IMAGE, model, clock.millis() - startedAt, failure);
      // 원래 예외는 요청 주소(계정 ID)를 담을 수 있어 요약으로 바꿔 던진다
      throw new IllegalStateException("cloudflare image failed : " + failure);
    } catch (RuntimeException e) {
      long elapsedMs = clock.millis() - startedAt;
      log.warn("[cloudflare image] failed : model={}, elapsedMs={}, error={}", model, elapsedMs,
        e.getClass().getSimpleName());
      aiCallLogService.recordFailure(AiCallType.CLOUDFLARE_IMAGE, model, elapsedMs, e.getClass().getSimpleName());
      throw new IllegalStateException("cloudflare image failed : " + e.getClass().getSimpleName());
    }
  }

  /// 기록용 실패 요약: HTTP 상태 + Cloudflare 오류 코드만 (토큰·계정 ID·본문 원문 제외)
  static String failureSummary(RestClientResponseException e) {
    String code = errorCodeOf(e.getResponseBodyAsString());
    return "status=" + e.getStatusCode().value() + (code == null ? "" : ", code=" + code);
  }

  /// 응답 본문의 첫 오류 코드 ({"errors":[{"code":4006,...}]})
  static String errorCodeOf(String body) {
    if (body == null) {
      return null;
    }
    Matcher matcher = ERROR_CODE.matcher(body);
    return matcher.find() ? matcher.group(1) : null;
  }

  private GeneratedImage toImage(CloudflareImageResponse response) {
    if (response == null || response.result() == null || response.result().image() == null
      || response.result().image().isBlank()) {
      throw new IllegalStateException("Cloudflare 응답에 이미지가 없음");
    }
    byte[] bytes = Base64.getDecoder().decode(response.result().image());
    return new GeneratedImage(bytes, extensionOf(bytes));
  }

  /// 앞 바이트로 형식 판별 (klein-4b 는 JPEG, 모델에 따라 PNG·WebP)
  static String extensionOf(byte[] bytes) {
    if (bytes.length >= 3 && (bytes[0] & 0xFF) == 0xFF && (bytes[1] & 0xFF) == 0xD8 && (bytes[2] & 0xFF) == 0xFF) {
      return "jpg";
    }
    if (bytes.length >= 12 && bytes[0] == 'R' && bytes[1] == 'I' && bytes[2] == 'F' && bytes[3] == 'F'
      && bytes[8] == 'W' && bytes[9] == 'E' && bytes[10] == 'B' && bytes[11] == 'P') {
      return "webp";
    }
    return "png";
  }

  record CloudflareImageResponse(Result result) {

    record Result(String image) {

    }
  }
}
