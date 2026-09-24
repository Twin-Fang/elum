package com.chuseok22.elumserver.ai.application.service;

import com.chuseok22.elumserver.ai.core.FluxSeed;
import com.chuseok22.elumserver.ai.core.GeneratedImage;
import com.chuseok22.elumserver.ai.core.ImageProvider;
import com.chuseok22.elumserver.ai.infrastructure.client.FluxImageClient;
import com.chuseok22.elumserver.ai.infrastructure.client.GeminiTextClient;
import com.chuseok22.elumserver.ai.infrastructure.client.ImageClientRouter;
import com.chuseok22.elumserver.ai.infrastructure.client.ImageGenerationClient;
import com.chuseok22.elumserver.member.infrastructure.entity.CharacterType;
import java.util.Optional;
import java.util.regex.Pattern;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Service;

/**
 * 카드 그림 한 장을 그린다 — 어느 제공자로, 실패하면 어디로 (#373).
 *
 * <p>일과 만들기({@code RoutineAiPipeline})와 카드 추가({@code RoutineStepImageFiller})가 같은 규칙을
 * 타도록 한 곳에 둔다.
 *
 * <ul>
 *   <li><b>FLUX 가 아니면 지금과 똑같다</b> — 고른 제공자에 한국어 카드 설명 그대로.</li>
 *   <li><b>FLUX 면 영어 장면이 필요하다.</b> 글 AI 가 같은 호출에서 준 한 줄을 쓰고, 없으면(보호자가
 *       직접 추가한 카드) 싼 글 모델로 한 줄 번역한다. seed 는 일과마다 고정한다.</li>
 *   <li><b>FLUX 쪽 무엇이 실패해도 그 카드만 OpenAI 로</b> — 키 없음·번역 실패·에러·타임아웃·
 *       잔액 소진(402/403). 두 호출 모두 각 클라이언트가 호출 기록에 남긴다.</li>
 * </ul>
 *
 * <p><b>품질 실패는 여기서 잡지 못한다.</b> schnell 이 동작을 못 그리거나 글자를 찍어도 API 는
 * 성공으로 끝난다(#373 원인 분석). 그런 카드를 OpenAI 로 돌릴 신호가 없다.
 */
@Slf4j
@Service
@RequiredArgsConstructor
public class CardImageGenerator {

  private static final Pattern HANGUL = Pattern.compile("[\\uAC00-\\uD7A3\\u3131-\\u318E]");
  // 한 줄이어야 한다. 이보다 길면 지시를 어긴 응답이라 보고 번역으로 돌린다.
  private static final int MAX_SCENE_LENGTH = 400;

  private final ImageClientRouter imageClientRouter;
  private final FluxImageClient fluxImageClient;
  private final GeminiTextClient imagePromptTranslator;

  /**
   * @param description   카드 설명(한국어). FLUX 가 아니거나 OpenAI 로 돌릴 때 그대로 쓴다
   * @param imagePromptEn 글 AI 가 같은 호출에서 준 영어 장면. 없으면 null
   * @param seedKey       {@link FluxSeed#routineKey} — 한 일과의 카드들이 같은 캐릭터로 나오게
   */
  public record CardImageRequest(
    String description, String imagePromptEn, CharacterType characterType, String seedKey
  ) {

  }

  public GeneratedImage generate(CardImageRequest request) {
    if (imageClientRouter.selected() != ImageProvider.FLUX) {
      return imageClientRouter.current().generateImage(request.description(), request.characterType());
    }
    if (!fluxImageClient.available()) {
      log.warn("FLUX 를 골랐지만 키가 없다 — 이 카드는 OpenAI 로 그린다");
      return fallbackToOpenAi(request, new IllegalStateException("FLUX 키가 없음"));
    }

    String scene = usableScene(request.imagePromptEn());
    if (scene == null) {
      try {
        scene = usableScene(imagePromptTranslator.translateImagePrompt(request.description()));
      } catch (Exception e) {
        log.warn("FLUX 용 영어 장면 번역 실패 — 이 카드는 OpenAI 로 그린다: description={}",
          request.description(), e);
        return fallbackToOpenAi(request, e);
      }
      if (scene == null) {
        log.warn("번역 결과를 FLUX 에 쓸 수 없다(비었거나 한국어·너무 김) — 이 카드는 OpenAI 로 그린다");
        return fallbackToOpenAi(request, new IllegalStateException("번역 결과를 쓸 수 없음"));
      }
    }

    try {
      return fluxImageClient.generate(scene, request.characterType(), FluxSeed.of(request.seedKey()));
    } catch (Exception e) {
      log.warn("FLUX 그림 실패 — 이 카드는 OpenAI 로 그린다: scene={}", scene, e);
      return fallbackToOpenAi(request, e);
    }
  }

  /// FLUX 에 넣을 수 있는 한 줄인가. 한국어가 섞이면 schnell 이 사람을 그렸다(#373 1차).
  private String usableScene(String raw) {
    if (raw == null) {
      return null;
    }
    String line = raw.replaceAll("\\s+", " ").trim();
    if (line.isEmpty() || line.length() > MAX_SCENE_LENGTH || HANGUL.matcher(line).find()) {
      return null;
    }
    return line;
  }

  /**
   * 그 카드만 OpenAI 로. OpenAI 도 못 쓰면 원래 실패를 그대로 올린다 — 부르는 쪽이 기본 그림으로
   * 덮는다(서비스 원칙 6).
   */
  private GeneratedImage fallbackToOpenAi(CardImageRequest request, Exception cause) {
    Optional<ImageGenerationClient> openAi =
      imageClientRouter.of(ImageProvider.OPENAI).filter(ImageGenerationClient::available);
    if (openAi.isEmpty()) {
      if (cause instanceof RuntimeException runtime) {
        throw runtime;
      }
      throw new IllegalStateException("FLUX 실패, OpenAI 도 쓸 수 없음", cause);
    }
    return openAi.get().generateImage(request.description(), request.characterType());
  }
}
