package com.chuseok22.elumserver.ai.infrastructure.client;

import com.chuseok22.elumserver.ai.application.service.PromptTemplateService;
import com.chuseok22.elumserver.ai.core.PromptKey;
import com.chuseok22.elumserver.common.infrastructure.properties.GeminiProperties;
import com.chuseok22.elumserver.member.infrastructure.entity.CharacterType;
import java.util.ArrayList;
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
  private final CharacterReferenceProvider characterReferenceProvider;

  // 옛 호출부(RoutineAiPipeline)가 Task 5에서 새 오버로드로 옮겨갈 때까지 남겨두는
  // 임시 위임 메서드. Task 5 완료 후에는 더 이상 쓰이지 않는다.
  public GeneratedImage generateImage(String stepDescription) {
    return generateImage(stepDescription, null);
  }

  public GeneratedImage generateImage(String stepDescription, CharacterType characterType) {
    String prefix = promptTemplateService.getContent(PromptKey.GEMINI_ROUTINE_IMAGE_PREFIX);
    return callGenerateImage(prefix, stepDescription, characterType);
  }

  // 옛 호출부(AdminPromptService)가 Task 7에서 새 오버로드로 옮겨갈 때까지 남겨두는
  // 임시 위임 메서드. Task 7 완료 후에는 더 이상 쓰이지 않는다.
  public GeneratedImage generateImageForTest(String prefix, String sampleInput) {
    return generateImageForTest(prefix, sampleInput, null);
  }

  // 관리자 테스트 전용: DB 조회 없이 전달받은 prefix를 그대로 사용한다.
  public GeneratedImage generateImageForTest(String prefix, String sampleInput, CharacterType characterType) {
    return callGenerateImage(prefix, sampleInput, characterType);
  }

  // characterType이 있으면 캐릭터 참조 이미지를 텍스트 파트보다 먼저 담아 함께 전송한다
  // (Gemini 멀티모달 입력 권장 순서). characterType이 null이면(온보딩에서 캐릭터를 아직
  // 선택하지 않은 회원) 지금까지와 동일하게 텍스트 파트만 전송해 루틴 생성이 끊기지 않게 한다.
  private GeneratedImage callGenerateImage(String prefix, String stepDescription, CharacterType characterType) {
    List<GeminiGenerateContentRequest.GeminiPart> parts = new ArrayList<>();
    if (characterType != null) {
      byte[] characterImage = characterReferenceProvider.get(characterType);
      String base64Image = Base64.getEncoder().encodeToString(characterImage);
      parts.add(GeminiGenerateContentRequest.GeminiPart.ofInlineData("image/png", base64Image));
    }
    parts.add(new GeminiGenerateContentRequest.GeminiPart(prefix + stepDescription));

    GeminiGenerateContentRequest request = new GeminiGenerateContentRequest(
      null,
      List.of(new GeminiGenerateContentRequest.GeminiContent("user", parts)),
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
