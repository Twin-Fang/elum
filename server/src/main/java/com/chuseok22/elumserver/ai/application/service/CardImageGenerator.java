package com.chuseok22.elumserver.ai.application.service;

import com.chuseok22.elumserver.ai.core.FluxSeed;
import com.chuseok22.elumserver.ai.core.CardScene;
import com.chuseok22.elumserver.ai.core.GeneratedImage;
import com.chuseok22.elumserver.ai.core.ImageProvider;
import com.chuseok22.elumserver.ai.infrastructure.client.EnglishSceneImageClient;
import com.chuseok22.elumserver.ai.infrastructure.client.GeminiTextClient;
import com.chuseok22.elumserver.ai.infrastructure.client.ImageClientRouter;
import com.chuseok22.elumserver.ai.infrastructure.client.ImageGenerationClient;
import com.chuseok22.elumserver.ai.infrastructure.client.ImageSafetyRejection;
import com.chuseok22.elumserver.common.infrastructure.logging.LogTextLength;
import com.chuseok22.elumserver.member.infrastructure.entity.CharacterType;
import com.chuseok22.elumserver.member.infrastructure.entity.ImageStyle;
import java.util.Optional;
import java.util.regex.Pattern;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Service;

/**
 * 카드 그림 한 장을 그린다 — 어느 제공자로, 실패하면 어디로.
 *
 * <p>일과 만들기({@code RoutineAiPipeline})와 카드 추가({@code RoutineStepImageFiller})가 같은 규칙을
 * 타도록 한 곳에 둔다.
 *
 * <ul>
 *   <li><b>영어 장면 제공자(FLUX·CLOUDFLARE)가 아니면 고른 제공자에 카드 설명, 제목, 영어 장면을 장면 정보로 싣는다.</b></li>
 *   <li><b>영어 장면 제공자면 영어 장면이 필요하다.</b> 글 AI 가 같은 호출에서 준 한 줄을 쓰고, 없으면(보호자가
 *       직접 추가한 카드) 싼 글 모델로 한 줄 번역한다. seed 는 일과마다 고정한다.</li>
 *   <li><b>그쪽 무엇이 실패해도 그 카드만 OpenAI 로</b> — 키 없음·번역 실패·에러·타임아웃·
 *       잔액·한도 소진. 두 호출 모두 각 클라이언트가 호출 기록에 남긴다.</li>
 *   <li><b>프로필 캐릭터를 그리지 않는 제공자(CLOUDFLARE)에서 넘어간 카드는 OpenAI 도 캐릭터 없이 그린다.</b></li>
 * </ul>
 *
 * <p><b>품질 실패는 여기서 잡지 못한다.</b> schnell 이 동작을 못 그리거나 글자를 찍어도 API 는
 * 성공으로 끝난다. 그런 카드를 OpenAI 로 돌릴 신호가 없다.
 */
@Slf4j
@Service
@RequiredArgsConstructor
public class CardImageGenerator {

  // 영어 한 줄에 섞이면 안 되는 글자: 한글, 가나, 한자 (악센트 라틴 é·ñ 는 허용)
  private static final Pattern NON_ENGLISH_SCRIPT = Pattern.compile(
    "[\\uAC00-\\uD7A3\\u3131-\\u318E\\u3040-\\u30FF\\u3400-\\u4DBF\\u4E00-\\u9FFF]");
  // 한 줄이어야 한다. 이보다 길면 지시를 어긴 응답이라 보고 번역으로 돌린다.
  private static final int MAX_SCENE_LENGTH = 400;

  private final ImageClientRouter imageClientRouter;
  private final GeminiTextClient imagePromptTranslator;

  /**
   * @param description   카드 설명(한국어). FLUX 가 아니거나 OpenAI 로 돌릴 때 그대로 쓴다
   * @param imagePromptEn 글 AI 가 같은 호출에서 준 영어 장면. 없으면 null
   * @param seedKey       {@link FluxSeed#routineKey} — 한 일과의 카드들이 같은 캐릭터로 나오게
   * @param imageStyle    이룸이의 그림 방식. null 이면 만화 — 기존 동작
   * @param routineTitle  일과 제목 (그림 AI 에게 어떤 일과인지 알리는 참고용). 직접 추가한 카드는 null
   * @param stepTitle     카드 제목. 직접 추가한 카드는 null
   * @param guardianRequest 고쳐서 다시 그리기의 보호자 요청 (칩 영어 문장 + Guardian note). 없으면 null
   */
  public record CardImageRequest(
    String description, String imagePromptEn, CharacterType characterType, String seedKey, ImageStyle imageStyle,
    String routineTitle, String stepTitle, String guardianRequest
  ) {

    public CardImageRequest {
      imageStyle = ImageStyle.orDefault(imageStyle);
    }

    /// 보호자 요청 없는 카드 (일과 만들기·카드 추가)
    public CardImageRequest(
      String description, String imagePromptEn, CharacterType characterType, String seedKey, ImageStyle imageStyle,
      String routineTitle, String stepTitle
    ) {
      this(description, imagePromptEn, characterType, seedKey, imageStyle, routineTitle, stepTitle, null);
    }

    /// 설명 한 줄만 받는 경로(실사·FLUX 번역)용: 설명 + 보호자 요청
    String descriptionWithGuardianRequest() {
      return guardianRequest == null ? description : description + " (" + guardianRequest + ")";
    }

    /// 설명만 있는 카드 (보호자가 직접 추가한 카드, 제목·영어 장면 없음)
    public CardImageRequest(
      String description, String imagePromptEn, CharacterType characterType, String seedKey, ImageStyle imageStyle
    ) {
      this(description, imagePromptEn, characterType, seedKey, imageStyle, null, null, null);
    }
  }

  public GeneratedImage generate(CardImageRequest request) {
    // AI 그림이 아닌 방식(그림 기호·이모지)은 호출부가 여기 오기 전에 건너뛴다. 그래도 왔다면 돈이 나가기 전에 막는다.
    if (!ImageStyle.orDefault(request.imageStyle()).drawsAiImages()) {
      throw new IllegalStateException("AI 그림을 만들지 않는 방식: " + request.imageStyle());
    }
    if (request.imageStyle() == ImageStyle.REALISTIC) {
      return generateRealistic(request);
    }
    ImageProvider selected = imageClientRouter.selected();
    if (selected == null || !selected.usesEnglishScene()) {
      return generateWithSafetyRetry(imageClientRouter.current(), request);
    }
    Optional<EnglishSceneImageClient> sceneClient = usableEnglishSceneClient(selected);
    if (sceneClient.isEmpty()) {
      log.info("[card image] {} unavailable or skipped today : fallback to OpenAI", selected);
      return fallbackToOpenAi(request, imageClientRouter.englishScene(selected).orElse(null),
        new IllegalStateException(selected + " 키가 없음"), translateRedrawSceneOrNull(request));
    }
    EnglishSceneImageClient client = sceneClient.get();

    // 보호자 요청이 있으면 글 AI 장면 대신 설명 + 요청을 번역 (요청이 장면에 들어가게)
    String scene = request.guardianRequest() == null ? usableScene(request.imagePromptEn()) : null;
    if (scene == null) {
      try {
        scene = usableScene(imagePromptTranslator.translateImagePrompt(request.descriptionWithGuardianRequest()));
      } catch (Exception e) {
        log.warn("영어 장면 번역 실패 — 이 카드는 OpenAI 로 그린다: provider={}, descriptionLength={}",
          selected, LogTextLength.of(request.description()), e);
        return fallbackToOpenAi(request, client, e, null);
      }
      if (scene == null) {
        log.warn("번역 결과를 영어 장면으로 쓸 수 없다(비었거나 영어가 아닌 글자·너무 김) — 이 카드는 OpenAI 로 그린다");
        return fallbackToOpenAi(request, client, new IllegalStateException("번역 결과를 쓸 수 없음"), null);
      }
    }

    try {
      // 다시 그리기는 요청이 바꾼 옷·머리를 생김새에서 빼는 경로로 (#1384)
      Integer seed = FluxSeed.of(request.seedKey());
      return request.guardianRequest() == null
        ? client.generate(scene, request.characterType(), seed)
        : client.generateWithGuardianRequest(scene, request.characterType(), seed);
    } catch (Exception e) {
      log.warn("{} 그림 실패 — 이 카드는 OpenAI 로 그린다: sceneLength={}", selected, LogTextLength.of(scene), e);
      // 다시 그리기면 Cloudflare 와 같은 요청 반영 장면을 OpenAI 에도 (첫 그림은 기존대로)
      return fallbackToOpenAi(request, client, e, request.guardianRequest() == null ? null : scene);
    }
  }

  /**
   * 실사 방식 — 캐릭터를 아예 쓰지 않는다(참조 이미지·생김새·"The character" 관례 없음).
   *
   * <p>영어 장면 제공자(FLUX·CLOUDFLARE)는 글 AI 가 준 {@code imagePromptEn} 을 쓰지 않는다. 그 문장은 "The character …" 관례라 실사에
   * 캐릭터를 부른다. 그래서 카드마다 실사용 번역 지시문으로 물건·장소 문장을 새로 만든다. 실패하면 그 카드만
   * OpenAI 로 돌리는 규칙은 만화와 같다.
   */
  private GeneratedImage generateRealistic(CardImageRequest request) {
    ImageProvider selected = imageClientRouter.selected();
    if (selected == null || !selected.usesEnglishScene()) {
      return imageClientRouter.current().generateRealisticImage(request.descriptionWithGuardianRequest());
    }
    Optional<EnglishSceneImageClient> sceneClient = usableEnglishSceneClient(selected);
    if (sceneClient.isEmpty()) {
      log.info("[card image] {} unavailable or skipped today : realistic fallback to OpenAI", selected);
      return fallbackToOpenAi(request, imageClientRouter.englishScene(selected).orElse(null),
        new IllegalStateException(selected + " 키가 없음"), null);
    }
    EnglishSceneImageClient client = sceneClient.get();

    String scene;
    try {
      scene = usableScene(imagePromptTranslator.translateRealisticImagePrompt(request.descriptionWithGuardianRequest()));
    } catch (Exception e) {
      log.warn("실사 장면 번역 실패 — 이 카드는 OpenAI 로 그린다: provider={}, descriptionLength={}",
        selected, LogTextLength.of(request.description()), e);
      return fallbackToOpenAi(request, client, e, null);
    }
    if (scene == null) {
      log.warn("실사 번역 결과를 영어 장면으로 쓸 수 없다(비었거나 영어가 아닌 글자·너무 김) — 이 카드는 OpenAI 로 그린다");
      return fallbackToOpenAi(request, client, new IllegalStateException("번역 결과를 쓸 수 없음"), null);
    }

    try {
      return client.generateRealistic(scene, FluxSeed.of(request.seedKey()));
    } catch (Exception e) {
      log.warn("{} 실사 그림 실패 — 이 카드는 OpenAI 로 그린다: sceneLength={}", selected, LogTextLength.of(scene), e);
      return fallbackToOpenAi(request, client, e, null);
    }
  }

  /// 고른 영어 장면 제공자를 지금 쓸 수 있는가 (키 없음·한도 소진이면 empty > 번역 없이 바로 OpenAI)
  private Optional<EnglishSceneImageClient> usableEnglishSceneClient(ImageProvider selected) {
    return imageClientRouter.englishScene(selected)
      .filter(ImageGenerationClient::available)
      .filter(client -> !client.isTemporarilySkipped());
  }

  /**
   * 다시 그리기 OpenAI 예비용 영어 장면: 설명 + 보호자 요청 번역 (Cloudflare 와 같은 번역)
   * 보호자 요청 없으면 null, 번역 실패·쓸 수 없는 결과도 null > 기존처럼 원래 설명으로 그림
   */
  private String translateRedrawSceneOrNull(CardImageRequest request) {
    if (request.guardianRequest() == null || request.imageStyle() == ImageStyle.REALISTIC) {
      return null;
    }
    try {
      String scene = usableScene(imagePromptTranslator.translateImagePrompt(request.descriptionWithGuardianRequest()));
      if (scene == null) {
        log.warn("[card image] redraw scene unusable : fallback to OpenAI with original description");
      }
      return scene;
    } catch (Exception e) {
      log.warn("[card image] redraw scene translate failed : fallback to OpenAI with original description, descriptionLength={}",
        LogTextLength.of(request.description()), e);
      return null;
    }
  }

  /// 영어 장면 제공자에 넣을 수 있는 한 줄인가. 한글·가나·한자가 섞이면 schnell 이 사람을 그렸다.
  private String usableScene(String raw) {
    if (raw == null) {
      return null;
    }
    String line = raw.replaceAll("\\s+", " ").trim();
    if (line.isEmpty() || line.length() > MAX_SCENE_LENGTH || NON_ENGLISH_SCRIPT.matcher(line).find()) {
      return null;
    }
    return line;
  }

  /// 같은 카드에서 프로필 캐릭터만 뺀 요청 (OpenAI 가 캐릭터 없는 인물로 그림)
  private static CardImageRequest withoutCharacter(CardImageRequest request) {
    return new CardImageRequest(request.description(), request.imagePromptEn(), null, request.seedKey(),
      request.imageStyle(), request.routineTitle(), request.stepTitle(), request.guardianRequest());
  }

  /**
   * 그 카드만 OpenAI 로. OpenAI 도 못 쓰면 원래 실패를 그대로 올린다 — 부르는 쪽이 기본 그림으로
   * 덮는다(서비스 원칙 6).
   *
   * @param redrawSceneEn 다시 그리기의 요청 반영 영어 장면 (Cloudflare 와 같은 문장). 없으면 null > 원래 설명
   */
  private GeneratedImage fallbackToOpenAi(
    CardImageRequest request, EnglishSceneImageClient failedClient, Exception cause, String redrawSceneEn
  ) {
    Optional<ImageGenerationClient> openAi =
      imageClientRouter.of(ImageProvider.OPENAI).filter(ImageGenerationClient::available);
    if (openAi.isEmpty()) {
      if (cause instanceof RuntimeException runtime) {
        throw runtime;
      }
      throw new IllegalStateException("영어 장면 제공자 실패, OpenAI 도 쓸 수 없음", cause);
    }
    // 카드 그림에서 캐릭터를 뺀 제공자(CLOUDFLARE)였으면 OpenAI 도 캐릭터 없이
    CardImageRequest fallbackRequest = failedClient != null && failedClient.shouldDropProfileCharacter()
      ? withoutCharacter(request)
      : request;
    if (fallbackRequest.imageStyle() == ImageStyle.REALISTIC) {
      return openAi.get().generateRealisticImage(fallbackRequest.descriptionWithGuardianRequest());
    }
    CardScene scene = redrawSceneEn == null ? toCardScene(fallbackRequest) : toRedrawCardScene(fallbackRequest, redrawSceneEn);
    return generateWithSafetyRetry(openAi.get(), fallbackRequest, scene);
  }

  /**
   * 안전 시스템이 거절하면 카드 제목만으로 한 번 더 시도: 장면 문장이 걸린 경우를 피함
   * 거절 사유는 로그로 남김 (원문 제외), 제목이 없는 카드나 재시도도 거절이면 그대로 던져 기본 그림으로 대체
   */
  private GeneratedImage generateWithSafetyRetry(ImageGenerationClient client, CardImageRequest request) {
    return generateWithSafetyRetry(client, request, toCardScene(request));
  }

  private GeneratedImage generateWithSafetyRetry(ImageGenerationClient client, CardImageRequest request, CardScene scene) {
    try {
      return client.generateCardImage(scene, request.characterType());
    } catch (RuntimeException rejected) {
      if (!ImageSafetyRejection.isRejection(rejected) || request.stepTitle() == null || request.stepTitle().isBlank()) {
        throw rejected;
      }
      String reasons = ImageSafetyRejection.reasonsOf(rejected);
      log.warn("[image safety] rejected 400 : reasons={}, provider={}, retry with title only", reasons, client.provider());
      try {
        GeneratedImage image = client.generateCardImage(
          CardScene.descriptionOnly(request.stepTitle()), request.characterType());
        log.info("[image safety] retry succeeded : reasons={}", reasons);
        return image;
      } catch (RuntimeException retryFailed) {
        log.warn("[image safety] retry failed : reasons={}, retryReasons={}", reasons, ImageSafetyRejection.reasonsOf(retryFailed));
        throw retryFailed;
      }
    }
  }

  /**
   * 다시 그리기 장면 (#1384): 요청 반영 영어 장면을 stepDescription 으로, 제목·원래 설명은 뺌 (#1378 fix_oa_scene)
   * guardianRequest 도 함께 실어 요청 규칙(GuardianRequestImageRules)이 우선 적용되게
   */
  static CardScene toRedrawCardScene(CardImageRequest request, String redrawSceneEn) {
    return new CardScene(null, null, redrawSceneEn, null, request.guardianRequest());
  }

  /// 글 AI 의 영어 장면은 한 줄·영어일 때만 싣는다 (그림 지시문 JSON 의 sceneDetail)
  private CardScene toCardScene(CardImageRequest request) {
    return new CardScene(
      request.routineTitle(), request.stepTitle(), request.description(), usableScene(request.imagePromptEn()),
      request.guardianRequest());
  }
}
