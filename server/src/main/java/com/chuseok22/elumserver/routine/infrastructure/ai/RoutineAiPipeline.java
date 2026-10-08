package com.chuseok22.elumserver.routine.infrastructure.ai;

import com.chuseok22.elumserver.ai.application.service.CardImageGenerator;
import com.chuseok22.elumserver.ai.application.service.PictogramCatalog;
import com.chuseok22.elumserver.ai.core.FluxSeed;
import com.chuseok22.elumserver.ai.core.ImageProvider;
import com.chuseok22.elumserver.ai.core.NicknamePlaceholder;
import com.chuseok22.elumserver.ai.core.RoutineQuestionDraft;
import com.chuseok22.elumserver.ai.core.RoutineStepDraft;
import com.chuseok22.elumserver.ai.core.GeneratedImage;
import com.chuseok22.elumserver.ai.infrastructure.client.ImageClientRouter;
import com.chuseok22.elumserver.ai.infrastructure.client.TextClientRouter;
import com.chuseok22.elumserver.common.infrastructure.exception.CustomException;
import com.chuseok22.elumserver.common.infrastructure.exception.ErrorCode;
import com.chuseok22.elumserver.common.locale.CurrentLocale;
import com.chuseok22.elumserver.routine.infrastructure.constant.RoutinePhrases;
import com.chuseok22.elumserver.member.infrastructure.entity.CharacterType;
import com.chuseok22.elumserver.member.infrastructure.entity.ImageStyle;
import com.chuseok22.elumserver.member.infrastructure.entity.SupportGoal;
import com.chuseok22.elumserver.routine.infrastructure.storage.RoutineImageStorage;
import com.fasterxml.jackson.databind.ObjectMapper;
import java.util.ArrayList;
import java.util.List;
import java.util.Map;
import java.util.Set;
import java.util.UUID;
import java.util.concurrent.CompletableFuture;
import java.util.concurrent.CompletionException;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;
import java.util.function.Supplier;
import java.util.stream.Collectors;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Component;

@Slf4j
@Component
@RequiredArgsConstructor
public class RoutineAiPipeline {

  private static final int MAX_STEPS = 10;

  // Spring Boot 4.1은 Jackson 3 기반이라 Jackson 2 ObjectMapper 빈이 자동 구성되지 않으므로
  // SensitiveInfoGuardService와 동일하게 직접 생성해서 쓴다.
  private final ObjectMapper objectMapper = new ObjectMapper();

  private final TextClientRouter textClientRouter;
  private final ImageClientRouter imageClientRouter;
  private final CardImageGenerator cardImageGenerator;
  private final RoutineImageStorage routineImageStorage;
  private final PictogramCatalog pictogramCatalog;

  /**
   * @param profileId FLUX seed 를 이 이룸이 + 일과 제목으로 정한다. 일과 id 는 저장 전이라 아직 없다
   * @param imageStyle 이룸이의 그림 방식. PHOTO_ONLY 면 그림 호출을 건너뛰고 imagePath 를 null 로 둔다
   */
  public RoutineGenerationResult generateForCreate(
    String sanitizedInputText, String nickname, Set<SupportGoal> supportGoals, List<String> maskedAnswers,
    CharacterType characterType, ImageStyle imageStyle, String profileId
  ) {
    // FLUX + 만화일 때만 카드마다 영어 장면을 같은 호출로 받는다 — 다른 제공자·방식은 쓰지 않을 출력 토큰이다.
    // 실사는 그 문장("The character" 관례)을 버리고 실사용 번역을 따로 하고, 직접 사진은 그림을 안 그린다.
    boolean includeImagePromptEn =
      imageClientRouter.selected() == ImageProvider.FLUX && ImageStyle.orDefault(imageStyle) == ImageStyle.CARTOON;
    RoutineStepDraft draft = parseDraft(
      () -> textClientRouter.current()
        .generateRoutineJson(sanitizedInputText, nickname, supportGoals, maskedAnswers, includeImagePromptEn)
    );
    // AI 는 이름 대신 자리표시 '이룸이' 로 쓴다. 그림은 그 문장 그대로 그려 이름이 그림 AI 에도 가지 않게
    // 하고, 결과를 돌려주기 직전에 실제 이름으로 바꾼다. seed 는 저장될 제목(이름 복원본)으로 정한다 —
    // 카드 추가가 저장된 제목으로 같은 seed 를 만들어 같은 캐릭터를 그리기 때문이다(seed 는 해시값이라 이름이 나가지 않는다).
    RoutineGenerationResult result = buildResult(
      draft, characterType, ImageStyle.orDefault(imageStyle), Map.of(),
      FluxSeed.routineKey(profileId, NicknamePlaceholder.restore(draft.title(), nickname)));
    return restoreNickname(result, nickname);
  }

  // 제목·카드 제목·설명의 자리표시를 이름으로 되돌린다. NicknamePlaceholder.restore 는 던지지 않고 실패하면 원문을
  // 돌려주므로(E10) 치환 때문에 일과 생성이 실패하지 않는다.
  private RoutineGenerationResult restoreNickname(RoutineGenerationResult result, String nickname) {
    List<GeneratedStep> steps = result.steps().stream()
      .map(step -> new GeneratedStep(
        step.order(),
        NicknamePlaceholder.restore(step.title(), nickname),
        NicknamePlaceholder.restore(step.description(), nickname),
        step.imagePath(),
        step.pictogramId()))
      .toList();
    return new RoutineGenerationResult(NicknamePlaceholder.restore(result.title(), nickname), steps, result.batchId());
  }

  private static final int MIN_OPTIONS = 3;

  // 도움 목표 기반 추가 질문 생성. 선택된 각 SupportGoal(PREPARE_ITEMS, PREPARE_NEW)마다
  // Gemini 응답에서 supportGoal이 일치하고 옵션이 3개 이상 남는 질문을 찾아 쓰고, 없으면
  // 그 목표만 fallbackQuestionItem(goal)로 대체한다 — 목표 하나가 무효여도 나머지 목표까지
  // 통째로 fallback 처리되던 이전 동작을 목표 단위로 좁혔다.
  public RoutineQuestionResult generateQuestion(
    String nickname, Set<SupportGoal> supportGoals, String sanitizedInputText
  ) {
    Map<String, RoutineQuestionResult.QuestionResultItem> validQuestionsByGoal = fetchValidQuestionsByGoal(
      nickname, supportGoals, sanitizedInputText
    );

    List<RoutineQuestionResult.QuestionResultItem> questions = new ArrayList<>();
    for (SupportGoal goal : List.of(SupportGoal.PREPARE_ITEMS, SupportGoal.PREPARE_NEW)) {
      if (!supportGoals.contains(goal)) {
        continue;
      }
      RoutineQuestionResult.QuestionResultItem valid = validQuestionsByGoal.get(goal.name());
      questions.add(valid != null ? valid : fallbackQuestionItem(goal));
    }
    return new RoutineQuestionResult(questions);
  }

  // Gemini 호출/파싱이 아예 실패하면 빈 맵을 반환해 모든 목표가 fallback을 쓰게 한다
  // (기존의 "전체 실패 시 전체 fallback"과 동일한 결과가 되지만, 응답이 왔는데 일부
  // 목표만 무효인 경우와 같은 경로로 처리한다).
  private Map<String, RoutineQuestionResult.QuestionResultItem> fetchValidQuestionsByGoal(
    String nickname, Set<SupportGoal> supportGoals, String sanitizedInputText
  ) {
    String json = null;
    try {
      json = textClientRouter.current()
        .generateQuestionJson(nickname, supportGoals, sanitizedInputText);
      RoutineQuestionDraft draft = objectMapper.readValue(json, RoutineQuestionDraft.class);
      if (draft.questions() == null) {
        return Map.of();
      }
      return draft.questions().stream()
        .filter(this::isValidQuestionItem)
        .collect(Collectors.toMap(
          RoutineQuestionDraft.QuestionItem::supportGoal,
          item -> new RoutineQuestionResult.QuestionResultItem(
            // AI 가 자리표시로 쓴 이름을 질문·선택지에서 되돌린다
            NicknamePlaceholder.restore(item.question(), nickname), toOptionResults(item.options(), nickname)),
          (first, second) -> first // 같은 supportGoal이 중복되면 먼저 나온 것만 채택한다.
        ));
    } catch (Exception e) {
      log.warn("AI 추가 질문 생성 실패, 목표별 고정 매핑으로 대체: response={}", json, e);
      return Map.of();
    }
  }

  // supportGoal이 PREPARE_ITEMS/PREPARE_NEW 중 하나이고, question이 비어있지 않고, 라벨이
  // 있는 옵션이 3개 이상 남아야 유효한 질문으로 인정한다.
  private boolean isValidQuestionItem(RoutineQuestionDraft.QuestionItem item) {
    boolean hasKnownGoal = "PREPARE_ITEMS".equals(item.supportGoal()) || "PREPARE_NEW".equals(item.supportGoal());
    boolean hasQuestion = item.question() != null && !item.question().isBlank();
    long validOptionCount = item.options() == null ? 0 : item.options().stream()
      .filter(option -> option.label() != null && !option.label().isBlank())
      .count();
    return hasKnownGoal && hasQuestion && validOptionCount >= MIN_OPTIONS;
  }

  // label이 없는 옵션은 아동에게 보여줄 수 없는 빈 버튼이 되므로 제외한다. emoji만 없으면
  // label은 유효하므로 옵션 자체를 버리지 않고 빈 문자열로 완화한다.
  private List<RoutineQuestionResult.QuestionResultItem.OptionResult> toOptionResults(
    List<RoutineQuestionDraft.QuestionItem.Option> options, String nickname
  ) {
    return options.stream()
      .filter(option -> option.label() != null && !option.label().isBlank())
      .map(option -> new RoutineQuestionResult.QuestionResultItem.OptionResult(
        option.emoji() == null ? "" : option.emoji(), NicknamePlaceholder.restore(option.label(), nickname)
      ))
      .toList();
  }

  // 목표 하나에 대한 고정 대체 질문. "직접 입력"은 보호자가 자유 텍스트를 입력하도록
  // 유도하는 항목이라 추천 답변 목록에 절대 포함하지 않는다(서비스 정책).
  // 문구는 요청 언어의 문구 파일에서 온다. 헤더 없는 옛 앱은 KO 라 지금과 같다.
  // 요청 스레드에서 불리므로 CurrentLocale 을 읽는다 — 다른 스레드로 옮기면 언어를 인자로 받게 바꾼다.
  private RoutineQuestionResult.QuestionResultItem fallbackQuestionItem(SupportGoal goal) {
    RoutinePhrases.FallbackQuestion fallback = RoutinePhrases.standard().fallbackQuestion(goal, CurrentLocale.get());
    return new RoutineQuestionResult.QuestionResultItem(
      fallback.question(),
      fallback.options().stream()
        .map(option -> new RoutineQuestionResult.QuestionResultItem.OptionResult(option.emoji(), option.label()))
        .toList()
    );
  }

  // AI 호출 자체(RestClient의 RestClientResponseException/ResourceAccessException 등)와
  // 응답 파싱을 하나의 try 블록에서 함께 처리한다. 호출과 파싱을 분리해두면 호출 실패가
  // 이 메서드 밖으로 그대로 전파돼 GlobalExceptionHandler의 범용 500 처리로 새어나가
  // ROUTINE_AI_GENERATION_FAILED(502)로 변환되지 않는다.
  private RoutineStepDraft parseDraft(Supplier<String> call) {
    String json = null;
    try {
      json = call.get();
      RoutineStepDraft draft = objectMapper.readValue(json, RoutineStepDraft.class);
      // title은 Routine.title이 NOT NULL이라, 스키마 위반으로 누락되면 DB 제약 위반(500)이
      // 아니라 여기서 먼저 502로 처리한다.
      if (draft.title() == null || draft.title().isBlank()) {
        log.warn("AI가 title 없이 응답함: response={}", json);
        throw new CustomException(ErrorCode.ROUTINE_AI_GENERATION_FAILED);
      }
      if (draft.steps() == null || draft.steps().isEmpty() || draft.steps().size() > MAX_STEPS) {
        log.warn("AI가 반환한 단계 수가 허용 범위를 벗어남: count={}, response={}",
          draft.steps() == null ? 0 : draft.steps().size(), json);
        throw new CustomException(ErrorCode.ROUTINE_STEP_LIMIT_EXCEEDED);
      }
      if (draft.steps().stream().anyMatch(step -> step.title() == null || step.title().isBlank())) {
        log.warn("AI가 일부 단계에 title 없이 응답함: response={}", json);
        throw new CustomException(ErrorCode.ROUTINE_AI_GENERATION_FAILED);
      }
      return normalizeOrder(draft);
    } catch (CustomException e) {
      throw e;
    } catch (Exception e) {
      log.warn("Gemini 텍스트 생성/응답 파싱 실패: response={}", json, e);
      throw new CustomException(ErrorCode.ROUTINE_AI_GENERATION_FAILED);
    }
  }

  // 모델이 order를 중복/누락되게 반환해도(예: 1,1,2) 이미지 파일 경로가 충돌하지 않도록,
  // 배열 순서를 유일한 기준으로 삼아 order를 1부터 다시 채번한다.
  //
  // pictogramId 도 여기서 확정한다. 카탈로그에 없거나 비었거나 null 이면(모델이 못 골랐거나 옛 프롬프트라 필드를
  // 빠뜨렸거나 환각) 폴백 id 로 바꾼다 — 카드에는 항상 그림이 있어야 하고, 이 때문에 카드 생성이 실패하면 안 된다.
  private RoutineStepDraft normalizeOrder(RoutineStepDraft draft) {
    List<RoutineStepDraft.StepDraft> normalized = new ArrayList<>();
    int fallbackCount = 0;
    for (int i = 0; i < draft.steps().size(); i++) {
      RoutineStepDraft.StepDraft step = draft.steps().get(i);
      String pictogramId = pictogramCatalog.resolve(step.pictogramId());
      // 골라 온 값이 유효하지 않아 폴백으로 바뀐 경우만 센다(카탈로그가 비어 null 인 경우는 세지 않는다).
      if (pictogramId != null && !pictogramCatalog.contains(step.pictogramId() == null ? null : step.pictogramId().trim())) {
        fallbackCount++;
      }
      normalized.add(new RoutineStepDraft.StepDraft(
        i + 1, step.title(), step.description(), step.imagePromptEn(), pictogramId));
    }
    // 폴백 비율이 높으면 스키마 설명·카탈로그를 손봐야 한다는 신호다.
    if (fallbackCount > 0) {
      log.info("픽토그램 폴백 적용: fallback={}/{}", fallbackCount, draft.steps().size());
    }
    return new RoutineStepDraft(draft.title(), normalized);
  }

  private RoutineGenerationResult buildResult(
    RoutineStepDraft draft, CharacterType characterType, ImageStyle imageStyle,
    Map<Integer, String> reusableImagePathsByOrder, String seedKey
  ) {
    String batchId = UUID.randomUUID().toString();
    ExecutorService executor = Executors.newVirtualThreadPerTaskExecutor();
    try {
      List<CompletableFuture<StepResult>> futures = draft.steps().stream()
        .map(stepDraft -> CompletableFuture.supplyAsync(
          () -> resolveStepResult(stepDraft, characterType, imageStyle, reusableImagePathsByOrder, seedKey), executor
        ))
        .toList();

      // 이미지 생성(HTTP 호출)까지만 병렬로 완료시키고, 파일 저장은 전부 성공한 뒤에만
      // 수행한다 — 일부 단계만 실패해도 이미 디스크에 쓰인 고아 이미지가 남지 않도록
      // 하기 위함(스펙: "모든 단계가 성공적으로 생성된 뒤에만 저장").
      // futures는 draft.steps() 순서 그대로이고 normalizeOrder가 이미 1..N으로 정렬해뒀으므로
      // 별도 정렬 없이도 steps는 순서대로 나온다.
      List<StepResult> stepResults = futures.stream().map(CompletableFuture::join).toList();

      List<GeneratedStep> steps = stepResults.stream()
        .map(result -> new GeneratedStep(
          result.stepDraft().order(),
          result.stepDraft().title(),
          result.stepDraft().description(),
          resolveImagePath(batchId, result),
          result.stepDraft().pictogramId()
        ))
        .toList();

      return new RoutineGenerationResult(draft.title(), steps, batchId);
    } catch (CompletionException e) {
      log.warn("단계별 이미지 생성 실패", e);
      throw new CustomException(ErrorCode.ROUTINE_AI_GENERATION_FAILED);
    } finally {
      executor.shutdown();
    }
  }

  // 단계 하나의 최종 imagePath를 결정한다.
  // - 재사용 경로가 있으면(revise) 그대로 쓴다.
  // - 새로 생성한 이미지가 있으면 파일로 저장하고 그 경로를 쓴다.
  // - 이미지 생성이 재시도까지 실패했으면(generatedImage=null) 저장을 건너뛰고 null을 반환한다.
  //   image_path가 nullable이므로 이미지 없이도 단계·일과가 저장된다(서비스 원칙 6).
  private String resolveImagePath(String batchId, StepResult result) {
    if (result.reusedImagePath() != null) {
      return result.reusedImagePath();
    }
    if (result.generatedImage() == null) {
      return null;
    }
    return routineImageStorage.save(batchId, result.stepDraft().order(), result.generatedImage());
  }

  private StepResult resolveStepResult(
    RoutineStepDraft.StepDraft stepDraft, CharacterType characterType, ImageStyle imageStyle,
    Map<Integer, String> reusableImagePathsByOrder, String seedKey
  ) {
    String reusablePath = reusableImagePathsByOrder.get(stepDraft.order());
    if (reusablePath != null) {
      return new StepResult(stepDraft, null, reusablePath);
    }
    // 직접 사진: 그림 호출 자체를 하지 않는다. 카드는 imagePath=null 로 저장되고(허용됨) 보호자가 사진을 넣는다.
    // 재시도·기본 그림 대체 경로도 타지 않는다 — 실패가 아니라 선택이다.
    if (imageStyle == ImageStyle.PHOTO_ONLY) {
      return new StepResult(stepDraft, null, null);
    }
    CardImageGenerator.CardImageRequest request = new CardImageGenerator.CardImageRequest(
      stepDraft.description(), stepDraft.imagePromptEn(), characterType, seedKey, imageStyle);
    return new StepResult(stepDraft, generateImageWithRetry(request), null);
  }

  // 이미지 단계 하나가 일시적으로 실패해도 전체 루틴 생성을 곧바로 포기하지 않도록, 실패한
  // 단계만 1회 재시도한다(루트 CLAUDE.md 서비스 원칙 6 — "AI 실패 시 fallback 필수" — 반영).
  // 재시도까지 실패하면 예외를 던지지 않고 null을 반환한다 — 이 단계만 이미지 없이(imagePath=null)
  // 저장하고 나머지 단계와 일과 자체는 살린다. 예외를 던지면 buildResult()에서 일과 전체가
  // ROUTINE_AI_GENERATION_FAILED로 죽어 서버에 저장조차 되지 않는다.
  // FLUX 실패의 OpenAI fallback 은 CardImageGenerator 안에서 이미 한 번 일어난다. 여기 재시도는 그
  // 둘이 다 실패했을 때의 것이다.
  private GeneratedImage generateImageWithRetry(CardImageGenerator.CardImageRequest request) {
    String description = request.description();
    try {
      return cardImageGenerator.generate(request);
    } catch (Exception first) {
      log.warn("이미지 생성 1차 실패, 1회 재시도: description={}", description, first);
      try {
        return cardImageGenerator.generate(request);
      } catch (Exception retry) {
        // 재시도까지 실패 — 이 단계만 이미지 없이 진행한다. 일과 전체를 포기하지 않는다.
        log.warn("이미지 생성 재시도까지 실패, 이미지 없이 진행: description={}", description, retry);
        return null;
      }
    }
  }

  private record StepResult(
    RoutineStepDraft.StepDraft stepDraft, GeneratedImage generatedImage, String reusedImagePath
  ) {

  }

  /**
   * @param batchId 이번 생성에서 만든 이미지가 들어간 폴더. 저장이 실패하면 서비스가
   *                이 폴더를 지워 고아 파일을 남기지 않는다.
   *                재사용 이미지(revise)는 다른 batchId에 있으므로 함께 지워지지 않는다.
   */
  public record RoutineGenerationResult(String title, List<GeneratedStep> steps, String batchId) {

  }

  /// @param pictogramId 무료 픽토그램 id. 검증·폴백을 마친 값이라 카탈로그가 있으면 항상 채워져 있다.
  ///                    그림 방식·이미지 성공 여부와 무관하게 저장한다(앱이 사진 > AI 그림 > 픽토그램 순으로 고른다).
  public record GeneratedStep(
    Integer order, String title, String description, String imagePath, String pictogramId
  ) {

    public GeneratedStep(Integer order, String title, String description, String imagePath) {
      this(order, title, description, imagePath, null);
    }
  }

  public record RoutineQuestionResult(List<QuestionResultItem> questions) {

    public record QuestionResultItem(String question, List<OptionResult> options) {

      public record OptionResult(String emoji, String label) {

      }
    }
  }
}
