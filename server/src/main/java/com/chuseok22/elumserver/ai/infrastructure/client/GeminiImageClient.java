package com.chuseok22.elumserver.ai.infrastructure.client;

import com.chuseok22.elumserver.ai.application.service.PromptTemplateService;
import com.chuseok22.elumserver.ai.core.PromptKey;
import com.chuseok22.elumserver.common.infrastructure.properties.GeminiProperties;
import com.chuseok22.elumserver.member.infrastructure.entity.CharacterType;
import java.util.ArrayList;
import java.util.Base64;
import java.util.List;
import java.util.Map;
import java.util.Optional;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Qualifier;
import org.springframework.stereotype.Component;
import org.springframework.web.client.RestClient;

@Slf4j
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

  public GeneratedImage generateImage(String stepDescription, CharacterType characterType) {
    String prefix = promptTemplateService.getContent(PromptKey.GEMINI_ROUTINE_IMAGE_PREFIX);
    return callGenerateImage(prefix, stepDescription, characterType);
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
    String promptText = prefix + stepDescription;
    parts.add(new GeminiGenerateContentRequest.GeminiPart(promptText));

    // responseModalities를 명시하지 않으면 이미지 생성 모델이 간헐적으로 텍스트만
    // 응답하고 이미지 데이터(inlineData)를 아예 포함하지 않는 경우가 있어(운영 로그에서
    // "Gemini 응답에 이미지 데이터가 없음" 실패로 확인됨), TEXT/IMAGE 모달리티를 모두
    // 요청해 이미지 출력을 강제한다.
    GeminiGenerateContentRequest request = new GeminiGenerateContentRequest(
      null,
      List.of(new GeminiGenerateContentRequest.GeminiContent("user", parts)),
      Map.of("responseModalities", List.of("TEXT", "IMAGE"))
    );

    long startedAt = System.currentTimeMillis();
    log.info(
      "Gemini 이미지 생성 호출 시작: model={}, apiKey={}, characterType={}, prompt={}",
      geminiProperties.imageModel(), geminiProperties.apiKey(), characterType, promptText
    );
    try {
      GeminiGenerateContentResponse response = geminiRestClient.post()
        .uri("/v1beta/models/{model}:generateContent", geminiProperties.imageModel())
        .header("x-goog-api-key", geminiProperties.apiKey())
        .body(request)
        .retrieve()
        .body(GeminiGenerateContentResponse.class);
      log.info(
        "Gemini 이미지 생성 호출 완료: model={}, elapsedMs={}, response={}",
        geminiProperties.imageModel(), System.currentTimeMillis() - startedAt, response
      );
      return extractImage(response);
    } catch (Exception e) {
      log.warn(
        "Gemini 이미지 생성 호출 실패: model={}, elapsedMs={}, characterType={}, prompt={}",
        geminiProperties.imageModel(), System.currentTimeMillis() - startedAt, characterType, promptText, e
      );
      throw e;
    }
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
