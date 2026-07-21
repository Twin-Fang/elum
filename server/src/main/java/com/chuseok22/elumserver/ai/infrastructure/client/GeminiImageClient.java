package com.chuseok22.elumserver.ai.infrastructure.client;

import com.chuseok22.elumserver.ai.application.service.PromptTemplateService;
import com.chuseok22.elumserver.ai.core.PromptKey;
import com.chuseok22.elumserver.common.infrastructure.properties.GeminiProperties;
import java.util.Base64;
import java.util.List;
import java.util.Optional;
import lombok.RequiredArgsConstructor;
import org.springframework.beans.factory.annotation.Qualifier;
import org.springframework.stereotype.Component;
import org.springframework.web.client.RestClient;

@Component
@RequiredArgsConstructor
public class GeminiImageClient {

  // GeminiConfig(Task 1)와 LocalLlmConfig가 각각 RestClient 빈을 하나씩 등록해 타입이
  // 같은 빈이 2개 존재하므로, 파라미터명-빈명 자동 매칭에만 기대지 않고 명시한다.
  @Qualifier("geminiRestClient")
  private final RestClient geminiRestClient;
  private final GeminiProperties geminiProperties;
  private final PromptTemplateService promptTemplateService;

  public GeneratedImage generateImage(String stepDescription) {
    String prefix = promptTemplateService.getContent(PromptKey.GEMINI_ROUTINE_IMAGE_PREFIX);
    return callGenerateImage(prefix, stepDescription);
  }

  // 관리자 테스트 전용: DB 조회 없이 전달받은 prefix를 그대로 사용한다.
  public GeneratedImage generateImageForTest(String prefix, String sampleInput) {
    return callGenerateImage(prefix, sampleInput);
  }

  private GeneratedImage callGenerateImage(String prefix, String stepDescription) {
    GeminiGenerateContentRequest request = new GeminiGenerateContentRequest(
      null,
      List.of(new GeminiGenerateContentRequest.GeminiContent(
        "user",
        List.of(new GeminiGenerateContentRequest.GeminiPart(prefix + stepDescription))
      )),
      null
    );

    GeminiGenerateContentResponse response = geminiRestClient.post()
      .uri("/v1beta/models/{model}:generateContent", geminiProperties.imageModel())
      .header("x-goog-api-key", geminiProperties.apiKey())
      .body(request)
      .retrieve()
      .body(GeminiGenerateContentResponse.class);

    return extractImage(response);
  }

  private GeneratedImage extractImage(GeminiGenerateContentResponse response) {
    Optional<GeminiGenerateContentResponse.Part> imagePart = Optional.ofNullable(response)
      .map(GeminiGenerateContentResponse::candidates)
      .filter(candidates -> !candidates.isEmpty())
      .map(candidates -> candidates.get(0))
      .map(GeminiGenerateContentResponse.Candidate::content)
      .map(GeminiGenerateContentResponse.Content::parts)
      .flatMap(parts -> parts.stream().filter(part -> part.inlineData() != null).findFirst());

    GeminiGenerateContentResponse.Part part = imagePart
      .orElseThrow(() -> new IllegalStateException("Gemini 응답에 이미지 데이터가 없음"));

    byte[] imageBytes = Base64.getDecoder().decode(part.inlineData().data());
    String extension = resolveExtension(part.inlineData().mimeType());
    return new GeneratedImage(imageBytes, extension);
  }

  private String resolveExtension(String mimeType) {
    if (mimeType == null) {
      return "png";
    }
    return switch (mimeType) {
      case "image/jpeg" -> "jpg";
      case "image/webp" -> "webp";
      default -> "png";
    };
  }

  public record GeneratedImage(byte[] bytes, String extension) {

  }
}
