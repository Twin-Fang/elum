package com.chuseok22.elumserver.routine.application.service;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.assertj.core.api.Assertions.tuple;
import static org.mockito.Mockito.any;
import static org.mockito.Mockito.doThrow;
import static org.mockito.Mockito.eq;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.verifyNoInteractions;
import static org.mockito.Mockito.when;

import com.chuseok22.elumserver.ai.application.service.SensitiveInfoGuardService;
import com.chuseok22.elumserver.common.infrastructure.exception.CustomException;
import com.chuseok22.elumserver.common.infrastructure.exception.ErrorCode;
import com.chuseok22.elumserver.member.application.service.Caller;
import com.chuseok22.elumserver.member.application.service.ProfileAccessGuard;
import com.chuseok22.elumserver.member.application.service.ProfileAccessGuard.ProfileAction;
import com.chuseok22.elumserver.member.application.service.ProfileAccessGuard.RoutineAction;
import com.chuseok22.elumserver.member.infrastructure.entity.CharacterType;
import com.chuseok22.elumserver.member.infrastructure.entity.Member;
import com.chuseok22.elumserver.member.infrastructure.entity.Profile;
import com.chuseok22.elumserver.member.infrastructure.entity.SupportGoal;
import com.chuseok22.elumserver.member.infrastructure.repository.ProfileRepository;
import com.chuseok22.elumserver.routine.application.dto.request.RewardUpdateRequest;
import com.chuseok22.elumserver.routine.application.dto.request.RoutineCreateRequest;
import com.chuseok22.elumserver.routine.application.dto.request.RoutineQuestionRequest;
import com.chuseok22.elumserver.routine.application.dto.request.RoutineStepCreateRequest;
import com.chuseok22.elumserver.routine.application.dto.request.RoutineStepUpdateRequest;
import com.chuseok22.elumserver.routine.application.dto.response.RecentRewardResponse;
import com.chuseok22.elumserver.routine.application.dto.response.RoutineQuestionResponse;
import com.chuseok22.elumserver.routine.application.dto.response.RoutineResponse;
import com.chuseok22.elumserver.routine.application.dto.response.RoutineSuggestionResponse;
import com.chuseok22.elumserver.routine.infrastructure.ai.RoutineAiPipeline;
import com.chuseok22.elumserver.routine.infrastructure.constant.RoutineSuggestionCatalog;
import com.chuseok22.elumserver.routine.infrastructure.entity.Routine;
import com.chuseok22.elumserver.routine.infrastructure.entity.RoutineStatus;
import com.chuseok22.elumserver.routine.infrastructure.entity.RoutineStep;
import com.chuseok22.elumserver.routine.infrastructure.guard.RoutineRequestCooldownGuard;
import com.chuseok22.elumserver.routine.infrastructure.repository.RoutineRepository;
import com.chuseok22.elumserver.routine.infrastructure.storage.RoutineImageStorage;
import java.time.LocalDateTime;
import java.util.List;
import java.util.Optional;
import java.util.Set;
import java.util.function.Consumer;
import java.util.stream.Stream;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.junit.jupiter.params.ParameterizedTest;
import org.junit.jupiter.params.provider.Arguments;
import org.junit.jupiter.params.provider.MethodSource;
import org.mockito.ArgumentCaptor;
import org.mockito.InjectMocks;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;

@ExtendWith(MockitoExtension.class)
class RoutineServiceTest {

  private static final Caller GUARDIAN = Caller.guardian("member-1");

  @Mock
  private RoutineRepository routineRepository;

  @Mock
  private RoutineImageStorage routineImageStorage;

  @Mock
  private ProfileRepository profileRepository;

  @Mock
  private ProfileAccessGuard profileAccessGuard;

  @Mock
  private RoutineAiPipeline routineAiPipeline;

  @Mock
  private RoutineRequestCooldownGuard routineRequestCooldownGuard;

  @Mock
  private RoutineQuotaGuard routineQuotaGuard;

  @Mock
  private AiDailyBudgetGuard aiDailyBudgetGuard;

  @InjectMocks
  private RoutineService routineService;

  @Test
  @DisplayName("본인 소유 일과의 단계 이미지를 조회하면 저장된 이미지 내용을 반환한다")
  void getStepImage_ownedRoutine_returnsImageContent() {
    Member member = new Member();
    member.setId("member-1");
    Profile profile = new Profile();
    profile.setId("profile-1");
    profile.setMember(member);
    Routine routine = new Routine();
    routine.setProfile(profile);
    RoutineStep step = new RoutineStep();
    step.setId("step-1");
    step.setImagePath("data/routine-images/batch-1/1.png");
    routine.setSteps(List.of(step));
    when(routineRepository.findById("routine-1")).thenReturn(Optional.of(routine));
    RoutineImageStorage.ImageContent expected =
      new RoutineImageStorage.ImageContent(new byte[]{1, 2, 3}, "image/png");
    when(routineImageStorage.read("data/routine-images/batch-1/1.png")).thenReturn(expected);

    RoutineImageStorage.ImageContent result = routineService.getStepImage(GUARDIAN, "routine-1", "step-1");

    assertThat(result).isEqualTo(expected);
  }

  @Test
  @DisplayName("다른 회원의 일과에 접근하면 ROUTINE_ACCESS_DENIED를 던진다")
  void getStepImage_notOwner_throwsAccessDenied() {
    Profile profile = new Profile();
    profile.setId("profile-1");
    Routine routine = new Routine();
    routine.setProfile(profile);
    when(routineRepository.findById("routine-1")).thenReturn(Optional.of(routine));
    doThrow(new CustomException(ErrorCode.ROUTINE_ACCESS_DENIED))
      .when(profileAccessGuard).checkRoutine(Caller.guardian("member-2"), "profile-1", null, RoutineAction.VIEW);

    assertThatThrownBy(() -> routineService.getStepImage(Caller.guardian("member-2"), "routine-1", "step-1"))
      .isInstanceOf(CustomException.class)
      .satisfies(e -> assertThat(((CustomException) e).getErrorCode())
        .isEqualTo(ErrorCode.ROUTINE_ACCESS_DENIED));
  }

  @Test
  @DisplayName("존재하지 않는 단계를 조회하면 ROUTINE_STEP_NOT_FOUND를 던진다")
  void getStepImage_missingStep_throwsStepNotFound() {
    Member member = new Member();
    member.setId("member-1");
    Profile profile = new Profile();
    profile.setId("profile-1");
    profile.setMember(member);
    Routine routine = new Routine();
    routine.setProfile(profile);
    routine.setSteps(List.of());
    when(routineRepository.findById("routine-1")).thenReturn(Optional.of(routine));

    assertThatThrownBy(() -> routineService.getStepImage(GUARDIAN, "routine-1", "missing-step"))
      .isInstanceOf(CustomException.class)
      .satisfies(e -> assertThat(((CustomException) e).getErrorCode())
        .isEqualTo(ErrorCode.ROUTINE_STEP_NOT_FOUND));
  }

  /// 지난 일과는 보낸 일과(CONFIRMED·COMPLETED)만 — 오늘 일과가 쓰는 두 상태와 같다.
  private static final List<RoutineStatus> SENT =
    List.of(RoutineStatus.CONFIRMED, RoutineStatus.COMPLETED);

  @Test
  @DisplayName("지난 일과는 회원 ID가 아니라 프로필 ID로 찾는다 — 잘못 넘기면 한 건도 걸리지 않는다")
  void getPastRoutines_queriesByProfileId() {
    Member member = new Member();
    member.setId("member-1");
    Profile profile = new Profile();
    profile.setId("profile-1");
    profile.setMember(member);
    when(profileAccessGuard.profileFor(eq(GUARDIAN), any(ProfileAction.class))).thenReturn(profile);
    when(routineRepository.findAllByProfileIdAndStatusInAndScheduledAtBeforeOrderByScheduledAtDesc(
      eq("profile-1"), any(), any(LocalDateTime.class))).thenReturn(List.of());

    routineService.getPastRoutines(GUARDIAN);

    // 프로필을 계정에서 떼어낸 뒤 두 값이 달라졌다. 회원 ID를 넘기면 쿼리는 성공하지만
    // 언제나 0건이라, 모든 보호자에게 지난 일과가 빈 칸으로 보인다.
    verify(routineRepository).findAllByProfileIdAndStatusInAndScheduledAtBeforeOrderByScheduledAtDesc(
      eq("profile-1"), any(), any(LocalDateTime.class));
    verify(routineRepository, never()).findAllByProfileIdAndStatusInAndScheduledAtBeforeOrderByScheduledAtDesc(
      eq("member-1"), any(), any(LocalDateTime.class));
  }

  @Test
  @DisplayName("지난 일과에 임시저장(PENDING_REVIEW)은 없다 — 이룸이에게 보낸 일과만 지난 일과다")
  void getPastRoutines_excludesPendingReview() {
    Member member = new Member();
    member.setId("member-1");
    Profile profile = new Profile();
    profile.setId("profile-1");
    profile.setMember(member);
    when(profileAccessGuard.profileFor(eq(GUARDIAN), any(ProfileAction.class))).thenReturn(profile);
    when(routineRepository.findAllByProfileIdAndStatusInAndScheduledAtBeforeOrderByScheduledAtDesc(
      eq("profile-1"), any(), any(LocalDateTime.class))).thenReturn(List.of());

    routineService.getPastRoutines(GUARDIAN);

    // 오늘 만들다 둔 임시저장은 scheduledAt 이 오늘이라 내일이면 "오늘 이전" 에 걸린다.
    // 상태로 거르지 않으면 보내지도 않은 일과가 지난 일과에 뜬다 (#387). 오늘 일과가
    // CONFIRMED·COMPLETED 만 쓰는 것과 같은 기준이다 (#353).
    ArgumentCaptor<List<RoutineStatus>> statuses = ArgumentCaptor.forClass(List.class);
    verify(routineRepository).findAllByProfileIdAndStatusInAndScheduledAtBeforeOrderByScheduledAtDesc(
      eq("profile-1"), statuses.capture(), any(LocalDateTime.class));
    assertThat(statuses.getValue())
      .containsExactlyInAnyOrderElementsOf(SENT)
      .doesNotContain(RoutineStatus.PENDING_REVIEW);
  }

  @Test
  @DisplayName("선택한 도움 목표가 없으면 질문 없이 required:false를 반환한다")
  void generateQuestion_noRelevantGoals_returnsNotRequired() {
    Member member = new Member();
    member.setId("member-1");
    Profile profile = new Profile();
    profile.setId("profile-1");
    profile.setMember(member);
    profile.setSupportGoals(Set.of(SupportGoal.STEP_BY_STEP));
    when(profileAccessGuard.profileFor(eq(GUARDIAN), any(ProfileAction.class))).thenReturn(profile);

    RoutineQuestionResponse response =
      routineService.generateQuestion(GUARDIAN, new RoutineQuestionRequest("내일 병원 가기"));

    assertThat(response.required()).isFalse();
    assertThat(response.questions()).isEmpty();
  }

  @Test
  @DisplayName("PREPARE_ITEMS를 선택했으면 AI 파이프라인 결과를 emoji/label 옵션으로 변환해 반환한다")
  void generateQuestion_relevantGoal_returnsQuestions() {
    Member member = new Member();
    member.setId("member-1");
    Profile profile = new Profile();
    profile.setId("profile-1");
    profile.setMember(member);
    profile.setNickname("하늘이");
    profile.setSupportGoals(Set.of(SupportGoal.PREPARE_ITEMS));
    when(profileAccessGuard.profileFor(eq(GUARDIAN), any(ProfileAction.class))).thenReturn(profile);
    RoutineAiPipeline.RoutineQuestionResult pipelineResult = new RoutineAiPipeline.RoutineQuestionResult(
      List.of(new RoutineAiPipeline.RoutineQuestionResult.QuestionResultItem(
        "챙겨야 하는 준비물이 있나요?",
        List.of(
          new RoutineAiPipeline.RoutineQuestionResult.QuestionResultItem.OptionResult("☔", "우산"),
          new RoutineAiPipeline.RoutineQuestionResult.QuestionResultItem.OptionResult("🧥", "우비")
        )
      ))
    );
    when(routineAiPipeline.generateQuestion(
      eq("하늘이"), eq(Set.of(SupportGoal.PREPARE_ITEMS)), eq("내일 비 오는 날 학교 가기")
    )).thenReturn(pipelineResult);

    RoutineQuestionResponse response =
      routineService.generateQuestion(GUARDIAN, new RoutineQuestionRequest("내일 비 오는 날 학교 가기"));

    assertThat(response.required()).isTrue();
    assertThat(response.questions()).hasSize(1);
    assertThat(response.questions().get(0).question()).isEqualTo("챙겨야 하는 준비물이 있나요?");
    assertThat(response.questions().get(0).options())
      .extracting(
        RoutineQuestionResponse.QuestionItem.OptionItem::emoji,
        RoutineQuestionResponse.QuestionItem.OptionItem::label
      )
      .containsExactly(tuple("☔", "우산"), tuple("🧥", "우비"));
  }

  @Test
  @DisplayName("추천 일과를 조회하면 카탈로그에서 요청한 개수만큼 무작위로 반환한다")
  void getSuggestions_validCount_returnsRequestedCountFromCatalog() {
    List<RoutineSuggestionResponse> result = routineService.getSuggestions(4);

    assertThat(result).hasSize(4);
    assertThat(result).isSubsetOf(RoutineSuggestionCatalog.ALL);
    assertThat(result).doesNotHaveDuplicates();
  }

  @Test
  @DisplayName("count가 카탈로그 전체 개수와 같으면 전체를 중복 없이 반환한다")
  void getSuggestions_countEqualsCatalogSize_returnsEntireCatalogWithoutDuplicates() {
    int catalogSize = RoutineSuggestionCatalog.ALL.size();

    List<RoutineSuggestionResponse> result = routineService.getSuggestions(catalogSize);

    assertThat(result).hasSize(catalogSize);
    assertThat(result).isSubsetOf(RoutineSuggestionCatalog.ALL);
    assertThat(result).doesNotHaveDuplicates();
  }

  @Test
  @DisplayName("count가 1 미만이면 INVALID_INPUT_VALUE를 던진다")
  void getSuggestions_countBelowMinimum_throwsInvalidInputValue() {
    assertThatThrownBy(() -> routineService.getSuggestions(0))
      .isInstanceOf(CustomException.class)
      .satisfies(e -> assertThat(((CustomException) e).getErrorCode())
        .isEqualTo(ErrorCode.INVALID_INPUT_VALUE));
  }

  @Test
  @DisplayName("count가 카탈로그 전체 개수를 초과하면 INVALID_INPUT_VALUE를 던진다")
  void getSuggestions_countAboveCatalogSize_throwsInvalidInputValue() {
    int tooMany = RoutineSuggestionCatalog.ALL.size() + 1;

    assertThatThrownBy(() -> routineService.getSuggestions(tooMany))
      .isInstanceOf(CustomException.class)
      .satisfies(e -> assertThat(((CustomException) e).getErrorCode())
        .isEqualTo(ErrorCode.INVALID_INPUT_VALUE));
  }

  @Test
  @DisplayName("쿨다운 중이면 회원/AI 파이프라인 조회 없이 ROUTINE_REQUEST_TOO_FREQUENT를 던진다")
  void create_cooldownActive_throwsWithoutTouchingMemberOrPipeline() {
    doThrow(new CustomException(ErrorCode.ROUTINE_REQUEST_TOO_FREQUENT))
      .when(routineRequestCooldownGuard).guard("member-1");

    assertThatThrownBy(() -> routineService.create(GUARDIAN, new RoutineCreateRequest(null, null, null, null, null)))
      .isInstanceOf(CustomException.class)
      .satisfies(e -> assertThat(((CustomException) e).getErrorCode())
        .isEqualTo(ErrorCode.ROUTINE_REQUEST_TOO_FREQUENT));
    verifyNoInteractions(profileAccessGuard, routineAiPipeline);
  }

  @Test
  @DisplayName("서비스 전체 하루 비용 상한에 닿으면 AI 를 부르기 전에 거절한다 (#368)")
  void create_dailyBudgetReached_rejectsBeforeCallingAi() {
    doThrow(new CustomException(ErrorCode.AI_DAILY_BUDGET_EXCEEDED))
      .when(aiDailyBudgetGuard).guard();

    assertThatThrownBy(() -> routineService.create(
      GUARDIAN, new RoutineCreateRequest("내일 병원 가기", null, null, null, null)))
      .isInstanceOf(CustomException.class)
      .satisfies(e -> assertThat(((CustomException) e).getErrorCode())
        .isEqualTo(ErrorCode.AI_DAILY_BUDGET_EXCEEDED));
    // 민감정보 검사(로컬 LLM)도 AI 호출이다. 거절할 거면 아무것도 부르지 않는다.
    verifyNoInteractions(routineAiPipeline);
  }

  @Test
  @DisplayName("일과 생성 시 회원이 설정한 캐릭터를 AI 파이프라인 생성 호출에 그대로 전달한다")
  void create_withMemberCharacter_passesCharacterToPipeline() {
    Member member = new Member();
    member.setId("member-1");
    Profile profile = new Profile();
    profile.setId("profile-1");
    profile.setMember(member);
    profile.setNickname("하늘이");
    profile.setSupportGoals(Set.of());
    profile.setCharacter(CharacterType.LULU);
    when(profileAccessGuard.profileFor(eq(GUARDIAN), any(ProfileAction.class))).thenReturn(profile);
    RoutineAiPipeline.RoutineGenerationResult generationResult = new RoutineAiPipeline.RoutineGenerationResult(
      "병원 다녀오기",
      List.of(new RoutineAiPipeline.GeneratedStep(1, "신발 신어요", "신발 신기", "data/routine-images/batch-1/1.png")),
      "batch-1"
    );
    when(routineAiPipeline.generateForCreate(any(), any(), any(), any(), eq(CharacterType.LULU), any()))
      .thenReturn(generationResult);
    when(routineRepository.save(any())).thenAnswer(invocation -> invocation.getArgument(0));

    routineService.create(GUARDIAN, new RoutineCreateRequest("내일 병원 가기", null, null, null, null));

    verify(routineAiPipeline).generateForCreate(
      eq("내일 병원 가기"), eq("하늘이"), eq(Set.of()), eq(List.of()), eq(CharacterType.LULU), any()
    );
  }

  /**
   * 이슈 #377 — AI DLP(로컬 LLM 마스킹)는 해커톤 POC 라 쓰지 않는다.
   *
   * <p>예전에는 입력 글과 답변 하나하나를 로컬 LLM 에 보내 가린 뒤 넘겼다. 이제는 가공하지
   * 않고 그대로 넘긴다 — 로컬 LLM 이 fail-open 이라 보장도 아니었고 호출마다 수 초가 걸렸다.
   * 가린 흔적(`<전화번호>`)이 생기지 않는지까지 본다.
   */
  @Test
  @DisplayName("일과 만들기는 입력 글과 답변을 가공하지 않고 그대로 AI 에 넘긴다 (이슈 #377)")
  void create_passesRawInputAndAnswersAsIs() {
    Profile profile = profileWithNickname("하늘이");
    when(routineAiPipeline.generateForCreate(any(), any(), any(), any(), eq(CharacterType.LULU), any()))
      .thenReturn(new RoutineAiPipeline.RoutineGenerationResult(
        "병원 다녀오기",
        List.of(new RoutineAiPipeline.GeneratedStep(1, "신발 신어요", "신발 신기",
          "data/routine-images/batch-1/1.png")),
        "batch-1"
      ));
    ArgumentCaptor<Routine> saved = ArgumentCaptor.forClass(Routine.class);
    when(routineRepository.save(saved.capture())).thenAnswer(invocation -> invocation.getArgument(0));

    routineService.create(GUARDIAN, new RoutineCreateRequest(
      "내일 병원 가기 010-1234-5678", null, List.of("우산", "엄마 010-9999-8888"), null, null));

    verify(routineAiPipeline).generateForCreate(
      eq("내일 병원 가기 010-1234-5678"), eq("하늘이"), any(),
      eq(List.of("우산", "엄마 010-9999-8888")), eq(CharacterType.LULU), any()
    );
    // 가공하지 않으므로 저장되는 두 칸이 같다. 컬럼 정리는 별도.
    assertThat(saved.getValue().getSanitizedInputText()).isEqualTo("내일 병원 가기 010-1234-5678");
  }

  @Test
  @DisplayName("추가 질문도 입력 글을 그대로 AI 에 넘긴다 (이슈 #377)")
  void generateQuestion_passesRawInputAsIs() {
    Profile profile = profileWithNickname("하늘이");
    profile.setSupportGoals(Set.of(SupportGoal.PREPARE_ITEMS));
    when(routineAiPipeline.generateQuestion(any(), any(), any()))
      .thenReturn(new RoutineAiPipeline.RoutineQuestionResult(List.of()));

    routineService.generateQuestion(GUARDIAN, new RoutineQuestionRequest("학교 가기 010-1234-5678"));

    verify(routineAiPipeline).generateQuestion(
      eq("하늘이"), eq(Set.of(SupportGoal.PREPARE_ITEMS)), eq("학교 가기 010-1234-5678"));
  }

  @Test
  @DisplayName("일과 서비스는 로컬 LLM 민감정보 검사에 의존하지 않는다 (이슈 #377)")
  void routineService_doesNotDependOnLocalLlmGuard() {
    // 필드로 다시 들어오면 누군가 호출을 되살린 것이다 — 약관은 가린다고 적지 않는다.
    assertThat(java.util.Arrays.stream(RoutineService.class.getDeclaredFields())
      .map(java.lang.reflect.Field::getType))
      .doesNotContain((Class) SensitiveInfoGuardService.class);
  }

  /**
   * 이슈 #215 — scheduledAt을 빼고 보내도 서버가 채운다.
   *
   * <p>DB는 NOT NULL인데 Swagger에는 필수 표시가 없었다. 빠뜨린 호출 하나가
   * AI를 다 태운 뒤 DB 제약에서 터졌다.
   */
  @Test
  @DisplayName("scheduledAt이 없으면 서버가 지금 시각으로 채운다 (이슈 #215)")
  void create_nullScheduledAt_serverFillsNow() {
    Profile profile = profileWithNickname("하늘이");
    stubCreatePipeline(profile);
    ArgumentCaptor<Routine> saved = ArgumentCaptor.forClass(Routine.class);
    when(routineRepository.save(saved.capture())).thenAnswer(i -> i.getArgument(0));

    LocalDateTime before = LocalDateTime.now();
    routineService.create(GUARDIAN, new RoutineCreateRequest("내일 병원 가기", null, null, null, null));

    assertThat(saved.getValue().getScheduledAt())
      .as("null로 저장하면 DB 제약에서 터진다")
      .isNotNull()
      .isAfterOrEqualTo(before);
  }

  /**
   * 이슈 #215 — 저장이 실패하면 방금 만든 이미지를 지운다.
   *
   * <p>이미지는 엔티티 저장 <b>전에</b> 디스크에 쓰인다. 저장이 실패하면 아무도
   * 참조하지 않는 파일이 남아 디스크가 계속 불어난다.
   */
  @Test
  @DisplayName("저장이 실패하면 생성한 이미지를 정리한다 (이슈 #215)")
  void create_saveFails_cleansUpGeneratedImages() {
    Profile profile = profileWithNickname("하늘이");
    stubCreatePipeline(profile);
    when(routineRepository.save(any())).thenThrow(new RuntimeException("DB 제약 위반"));

    assertThatThrownBy(() ->
      routineService.create(GUARDIAN, new RoutineCreateRequest("내일 병원 가기", null, null, null, null)))
      .isInstanceOf(RuntimeException.class);

    verify(routineImageStorage).deleteBatch("batch-1");
  }

  private Profile profileWithNickname(String nickname) {
    Profile profile = new Profile();
    profile.setNickname(nickname);
    profile.setCharacter(CharacterType.LULU);
    when(profileAccessGuard.profileFor(eq(GUARDIAN), any(ProfileAction.class))).thenReturn(profile);
    return profile;
  }

  private void stubCreatePipeline(Profile profile) {
    when(routineAiPipeline.generateForCreate(any(), any(), any(), any(), eq(CharacterType.LULU), any()))
      .thenReturn(new RoutineAiPipeline.RoutineGenerationResult(
        "병원 다녀오기",
        List.of(new RoutineAiPipeline.GeneratedStep(1, "신발 신어요", "신발 신기",
          "data/routine-images/batch-1/1.png")),
        "batch-1"
      ));
  }

  @Test
  @DisplayName("오늘 일과를 조회하면 CONFIRMED/COMPLETED 상태의 오늘 범위 일과만 반환한다")
  void getTodayRoutines_returnsConfirmedAndCompletedRoutinesForToday() {
    Member member = new Member();
    member.setId("member-1");
    Profile profile = new Profile();
    profile.setId("profile-1");
    profile.setMember(member);
    Routine routine = new Routine();
    routine.setId("routine-1");
    routine.setTitle("병원 다녀오기");
    routine.setProfile(profile);
    routine.setStatus(RoutineStatus.CONFIRMED);
    routine.setSteps(List.of());
    // 프로필로 조회해야 한다. 예전에는 memberId를 그대로 넘겨 아무것도 걸리지 않았는데,
    // 이 테스트가 그 값을 기대하고 있어 버그가 통과로 남아 있었다.
    when(profileAccessGuard.profileFor(eq(GUARDIAN), any(ProfileAction.class))).thenReturn(profile);
    when(routineRepository.findTodayOrdered(
      eq("profile-1"), eq(List.of(RoutineStatus.CONFIRMED, RoutineStatus.COMPLETED)), any(), any()
    )).thenReturn(List.of(routine));

    List<RoutineResponse> result = routineService.getTodayRoutines(GUARDIAN);

    assertThat(result).hasSize(1);
    assertThat(result.get(0).id()).isEqualTo("routine-1");
    verify(routineRepository).findTodayOrdered(
      eq("profile-1"), eq(List.of(RoutineStatus.CONFIRMED, RoutineStatus.COMPLETED)), any(), any()
    );
  }

  // --- 오프라인 퍼스트 일괄 반영 (이슈 #140) ---

  private Routine confirmedRoutine(Profile profile, int stepCount) {
    Routine routine = new Routine();
    routine.setId("routine-1");
    routine.setProfile(profile);
    routine.setStatus(RoutineStatus.CONFIRMED);
    java.util.List<RoutineStep> steps = new java.util.ArrayList<>();
    for (int i = 1; i <= stepCount; i++) {
      RoutineStep step = new RoutineStep();
      step.setId("step-" + i);
      step.setStepOrder(i);
      step.setDescription("단계 " + i);
      step.setCompleted(false);
      steps.add(step);
    }
    routine.setSteps(steps);
    return routine;
  }

  private Profile profileWithStars(int stars) {
    Member member = new Member();
    member.setId("member-1");
    Profile profile = new Profile();
    profile.setId("profile-1");
    profile.setMember(member);
    profile.setTotalStars(stars);
    return profile;
  }

  @Test
  @DisplayName("syncProgress: 부분 집합을 보내면 해당 단계만 완료되고 별은 늘어난 수만큼 오른다")
  void syncProgress_partialSet_marksOnlyThoseAndAddsStars() {
    Profile profile = profileWithStars(0);
    Routine routine = confirmedRoutine(profile, 3);
    when(routineRepository.findById("routine-1")).thenReturn(Optional.of(routine));

    RoutineResponse response = routineService.syncProgress(GUARDIAN, "routine-1", List.of("step-1", "step-2"));

    assertThat(routine.getSteps()).extracting(RoutineStep::getCompleted).containsExactly(true, true, false);
    assertThat(routine.getSteps().get(0).getCompletedAt()).isNotNull();
    assertThat(routine.getSteps().get(2).getCompletedAt()).isNull();
    assertThat(profile.getTotalStars()).isEqualTo(2);
    assertThat(routine.getStatus()).isEqualTo(RoutineStatus.CONFIRMED);
    assertThat(response.progressPercent()).isEqualTo(66);
  }

  @Test
  @DisplayName("syncProgress: 전부 보내면 COMPLETED가 되고 completedAt이 찍힌다")
  void syncProgress_allSteps_completesRoutine() {
    Routine routine = confirmedRoutine(profileWithStars(0), 2);
    when(routineRepository.findById("routine-1")).thenReturn(Optional.of(routine));

    routineService.syncProgress(GUARDIAN, "routine-1", List.of("step-1", "step-2"));

    assertThat(routine.getStatus()).isEqualTo(RoutineStatus.COMPLETED);
    assertThat(routine.getCompletedAt()).isNotNull();
  }

  @Test
  @DisplayName("syncProgress: 완료였던 단계를 집합에서 빼면 해제되고 별이 그만큼 내려가며 CONFIRMED로 돌아온다")
  void syncProgress_removingSteps_uncompletesAndSubtractsStars() {
    Profile profile = profileWithStars(3);
    Routine routine = confirmedRoutine(profile, 3);
    routine.getSteps().forEach(step -> {
      step.setCompleted(true);
      step.setCompletedAt(java.time.LocalDateTime.now());
    });
    routine.setStatus(RoutineStatus.COMPLETED);
    routine.setCompletedAt(java.time.LocalDateTime.now());
    when(routineRepository.findById("routine-1")).thenReturn(Optional.of(routine));

    routineService.syncProgress(GUARDIAN, "routine-1", List.of("step-1"));

    assertThat(routine.getSteps()).extracting(RoutineStep::getCompleted).containsExactly(true, false, false);
    assertThat(routine.getSteps().get(1).getCompletedAt()).isNull();
    assertThat(profile.getTotalStars()).isEqualTo(1);
    assertThat(routine.getStatus()).isEqualTo(RoutineStatus.CONFIRMED);
    assertThat(routine.getCompletedAt()).isNull();
  }

  @Test
  @DisplayName("syncProgress: 같은 집합을 두 번 보내도 별이 더 오르지 않는다 (멱등)")
  void syncProgress_sameSetTwice_isIdempotent() {
    Profile profile = profileWithStars(0);
    Routine routine = confirmedRoutine(profile, 2);
    when(routineRepository.findById("routine-1")).thenReturn(Optional.of(routine));

    routineService.syncProgress(GUARDIAN, "routine-1", List.of("step-1"));
    routineService.syncProgress(GUARDIAN, "routine-1", List.of("step-1"));

    assertThat(profile.getTotalStars()).isEqualTo(1);
  }

  @Test
  @DisplayName("syncProgress: 순서를 건너뛴 집합도 그대로 받아들인다")
  void syncProgress_outOfOrderSet_isAccepted() {
    Routine routine = confirmedRoutine(profileWithStars(0), 3);
    when(routineRepository.findById("routine-1")).thenReturn(Optional.of(routine));

    routineService.syncProgress(GUARDIAN, "routine-1", List.of("step-3"));

    assertThat(routine.getSteps()).extracting(RoutineStep::getCompleted).containsExactly(false, false, true);
  }

  @Test
  @DisplayName("syncProgress: 별이 0인 상태에서 해제 요청이 와도 음수가 되지 않는다")
  void syncProgress_neverGoesBelowZeroStars() {
    Profile profile = profileWithStars(0);
    Routine routine = confirmedRoutine(profile, 1);
    routine.getSteps().get(0).setCompleted(true);
    when(routineRepository.findById("routine-1")).thenReturn(Optional.of(routine));

    routineService.syncProgress(GUARDIAN, "routine-1", List.of());

    assertThat(profile.getTotalStars()).isZero();
  }

  @Test
  @DisplayName("syncProgress: 승인 전 일과면 ROUTINE_INVALID_STATUS를 던진다")
  void syncProgress_pendingReview_throws() {
    Routine routine = confirmedRoutine(profileWithStars(0), 1);
    routine.setStatus(RoutineStatus.PENDING_REVIEW);
    when(routineRepository.findById("routine-1")).thenReturn(Optional.of(routine));

    assertThatThrownBy(() -> routineService.syncProgress(GUARDIAN, "routine-1", List.of("step-1")))
      .isInstanceOf(CustomException.class)
      .satisfies(e -> assertThat(((CustomException) e).getErrorCode()).isEqualTo(ErrorCode.ROUTINE_INVALID_STATUS));
  }

  @Test
  @DisplayName("syncProgress: 이 일과에 없는 단계 id가 섞이면 ROUTINE_STEP_NOT_FOUND를 던진다")
  void syncProgress_unknownStepId_throws() {
    Routine routine = confirmedRoutine(profileWithStars(0), 1);
    when(routineRepository.findById("routine-1")).thenReturn(Optional.of(routine));

    assertThatThrownBy(() -> routineService.syncProgress(GUARDIAN, "routine-1", List.of("step-1", "ghost")))
      .isInstanceOf(CustomException.class)
      .satisfies(e -> assertThat(((CustomException) e).getErrorCode()).isEqualTo(ErrorCode.ROUTINE_STEP_NOT_FOUND));
  }

  // --- 순서 바꾸기 (이슈 #258) ---

  // --- 행동 단계 순서 변경 (이슈 #267) ---

  private RoutineStep stepOf(String id, int order) {
    RoutineStep step = new RoutineStep();
    step.setId(id);
    step.setStepOrder(order);
    return step;
  }

  private Routine routineWithSteps(String id, Profile profile, RoutineStep... steps) {
    Routine routine = ownedRoutine(id, profile);
    routine.getSteps().addAll(List.of(steps));
    return routine;
  }

  @Test
  @DisplayName("보낸 차례대로 1부터 번호가 붙는다")
  void reorderSteps_assignsSequentialOrder() {
    Profile profile = profileOf("profile-1", "member-1");
    RoutineStep a = stepOf("s-a", 1);
    RoutineStep b = stepOf("s-b", 2);
    RoutineStep c = stepOf("s-c", 3);
    Routine routine = routineWithSteps("r-1", profile, a, b, c);
    when(routineRepository.findById("r-1")).thenReturn(Optional.of(routine));

    routineService.reorderSteps(GUARDIAN, "r-1", List.of("s-c", "s-a", "s-b"));

    assertThat(c.getStepOrder()).isEqualTo(1);
    assertThat(a.getStepOrder()).isEqualTo(2);
    assertThat(b.getStepOrder()).isEqualTo(3);
  }

  @Test
  @DisplayName("일부만 보내면 거부한다 — 빠진 단계의 차례를 알 수 없다")
  void reorderSteps_partialList_rejected() {
    Profile profile = profileOf("profile-1", "member-1");
    RoutineStep a = stepOf("s-a", 1);
    RoutineStep b = stepOf("s-b", 2);
    Routine routine = routineWithSteps("r-1", profile, a, b);
    when(routineRepository.findById("r-1")).thenReturn(Optional.of(routine));

    assertThatThrownBy(() -> routineService.reorderSteps(GUARDIAN, "r-1", List.of("s-b")))
      .isInstanceOf(CustomException.class)
      .satisfies(e -> assertThat(((CustomException) e).getErrorCode())
        .isEqualTo(ErrorCode.INVALID_INPUT_VALUE));

    // 아무것도 바뀌지 않아야 한다 — 절반만 반영되면 화면과 서버가 어긋난다.
    assertThat(a.getStepOrder()).isEqualTo(1);
    assertThat(b.getStepOrder()).isEqualTo(2);
  }

  @Test
  @DisplayName("없는 단계가 섞이면 아무것도 바꾸지 않는다")
  void reorderSteps_unknownStep_changesNothing() {
    Profile profile = profileOf("profile-1", "member-1");
    RoutineStep a = stepOf("s-a", 1);
    RoutineStep b = stepOf("s-b", 2);
    Routine routine = routineWithSteps("r-1", profile, a, b);
    when(routineRepository.findById("r-1")).thenReturn(Optional.of(routine));

    assertThatThrownBy(
      () -> routineService.reorderSteps(GUARDIAN, "r-1", List.of("s-a", "없는것")))
      .isInstanceOf(CustomException.class)
      .satisfies(e -> assertThat(((CustomException) e).getErrorCode())
        .isEqualTo(ErrorCode.ROUTINE_STEP_NOT_FOUND));

    assertThat(a.getStepOrder()).isEqualTo(1);
    assertThat(b.getStepOrder()).isEqualTo(2);
  }

  @Test
  @DisplayName("같은 단계가 두 번 오면 거부한다 — 번호가 겹쳐 순서가 뒤엉킨다")
  void reorderSteps_duplicateId_rejected() {
    assertThatThrownBy(
      () -> routineService.reorderSteps(GUARDIAN, "r-1", List.of("s-a", "s-a")))
      .isInstanceOf(CustomException.class)
      .satisfies(e -> assertThat(((CustomException) e).getErrorCode())
        .isEqualTo(ErrorCode.INVALID_INPUT_VALUE));
  }

  @Test
  @DisplayName("남의 일과는 건드릴 수 없다")
  void reorderSteps_foreignRoutine_rejected() {
    Profile others = profileOf("profile-2", "member-2");
    Routine routine = routineWithSteps("r-1", others, stepOf("s-a", 1));
    when(routineRepository.findById("r-1")).thenReturn(Optional.of(routine));
    doThrow(new CustomException(ErrorCode.ROUTINE_ACCESS_DENIED))
      .when(profileAccessGuard).checkRoutine(GUARDIAN, "profile-2", null, RoutineAction.EDIT);

    assertThatThrownBy(() -> routineService.reorderSteps(GUARDIAN, "r-1", List.of("s-a")))
      .isInstanceOf(CustomException.class)
      .satisfies(e -> assertThat(((CustomException) e).getErrorCode())
        .isEqualTo(ErrorCode.ROUTINE_ACCESS_DENIED));
  }

  @Test
  @DisplayName("빈 목록은 아무 일도 하지 않는다")
  void reorderSteps_emptyList_noop() {
    routineService.reorderSteps(GUARDIAN, "r-1", List.of());
    // 조회조차 하지 않는다
    verify(routineRepository, never()).findById("r-1");
  }

  private Routine ownedRoutine(String id, Profile profile) {
    Routine routine = new Routine();
    routine.setId(id);
    routine.setProfile(profile);
    routine.setDisplayOrder(0);
    return routine;
  }

  private Profile profileOf(String profileId, String memberId) {
    Member member = new Member();
    member.setId(memberId);
    Profile profile = new Profile();
    profile.setId(profileId);
    profile.setMember(member);
    return profile;
  }

  @Test
  @DisplayName("보낸 차례대로 1부터 번호가 붙는다")
  void reorder_assignsSequentialOrder() {
    Profile profile = profileOf("profile-1", "member-1");
    when(profileAccessGuard.profileFor(eq(GUARDIAN), any(ProfileAction.class))).thenReturn(profile);
    Routine a = ownedRoutine("r-a", profile);
    Routine b = ownedRoutine("r-b", profile);
    Routine c = ownedRoutine("r-c", profile);
    when(routineRepository.findAllById(List.of("r-c", "r-a", "r-b")))
      .thenReturn(List.of(a, b, c));

    routineService.reorder(GUARDIAN, List.of("r-c", "r-a", "r-b"));

    assertThat(c.getDisplayOrder()).isEqualTo(1);
    assertThat(a.getDisplayOrder()).isEqualTo(2);
    assertThat(b.getDisplayOrder()).isEqualTo(3);
  }

  @Test
  @DisplayName("남의 일과가 섞이면 아무것도 바꾸지 않는다")
  void reorder_foreignRoutine_changesNothing() {
    Profile mine = profileOf("profile-1", "member-1");
    Profile others = profileOf("profile-2", "member-2");
    when(profileAccessGuard.profileFor(eq(GUARDIAN), any(ProfileAction.class))).thenReturn(mine);
    Routine a = ownedRoutine("r-a", mine);
    Routine stranger = ownedRoutine("r-x", others);
    when(routineRepository.findAllById(List.of("r-a", "r-x")))
      .thenReturn(List.of(a, stranger));

    assertThatThrownBy(() -> routineService.reorder(GUARDIAN, List.of("r-a", "r-x")))
      .isInstanceOf(CustomException.class)
      .satisfies(e -> assertThat(((CustomException) e).getErrorCode())
        .isEqualTo(ErrorCode.ROUTINE_ACCESS_DENIED));

    assertThat(a.getDisplayOrder()).isZero();
    assertThat(stranger.getDisplayOrder()).isZero();
  }

  @Test
  @DisplayName("없는 일과가 섞이면 거부한다 — 절반만 반영되면 화면과 서버가 어긋난다")
  void reorder_missingRoutine_rejected() {
    Profile profile = profileOf("profile-1", "member-1");
    when(profileAccessGuard.profileFor(eq(GUARDIAN), any(ProfileAction.class))).thenReturn(profile);
    when(routineRepository.findAllById(List.of("r-a", "없는것")))
      .thenReturn(List.of(ownedRoutine("r-a", profile)));

    assertThatThrownBy(() -> routineService.reorder(GUARDIAN, List.of("r-a", "없는것")))
      .isInstanceOf(CustomException.class)
      .satisfies(e -> assertThat(((CustomException) e).getErrorCode())
        .isEqualTo(ErrorCode.ROUTINE_NOT_FOUND));
  }

  @Test
  @DisplayName("같은 일과가 두 번 오면 거부한다 — 번호가 겹쳐 순서가 뒤엉킨다")
  void reorder_duplicateIds_rejected() {
    assertThatThrownBy(() -> routineService.reorder(GUARDIAN, List.of("r-a", "r-a")))
      .isInstanceOf(CustomException.class)
      .satisfies(e -> assertThat(((CustomException) e).getErrorCode())
        .isEqualTo(ErrorCode.INVALID_INPUT_VALUE));
  }

  @Test
  @DisplayName("빈 목록은 조회조차 하지 않는다")
  void reorder_emptyList_noop() {
    routineService.reorder(GUARDIAN, List.of());
    routineService.reorder(GUARDIAN, null);

    verify(routineRepository, never()).findAllById(any());
  }
  @Test
  @DisplayName("최근 보상은 겹치지 않는 것으로 넷까지 준다 — 보상 설정 시안(1082:4801)이 칩 넷을 2·2로 그린다")
  void getRecentRewards_returnsUpToFourDistinctNewestFirst() {
    Member member = new Member();
    member.setId("member-1");
    Profile profile = new Profile();
    profile.setId("profile-1");
    profile.setMember(member);
    when(profileAccessGuard.profileFor(eq(GUARDIAN), any(ProfileAction.class))).thenReturn(profile);
    // 최신순. 같은 보상이 두 번, 빈 보상이 한 번 섞여 있다 — 둘 다 칸을 차지하면 안 된다.
    List<Routine> newestFirst = List.of(
      routineWithReward("인형놀이 20분"),
      routineWithReward("젤리 4개 먹기"),
      routineWithReward("인형놀이 20분"),
      routineWithReward("  "),
      routineWithReward("20분 산책하기"),
      routineWithReward("거실에서 저녁먹기"),
      routineWithReward("유튜브 10분 보기")
    );
    when(routineRepository.findTop30ByProfileIdAndRewardTextIsNotNullOrderByCreatedAtDesc("profile-1"))
      .thenReturn(newestFirst);

    List<RecentRewardResponse> result = routineService.getRecentRewards(GUARDIAN);

    // 넷째까지 온다. 셋에서 끊으면 시안의 둘째 줄이 한 칸만 차서 2·1 로 선다 (#380).
    assertThat(result).extracting(RecentRewardResponse::rewardText)
      .containsExactly("인형놀이 20분", "젤리 4개 먹기", "20분 산책하기", "거실에서 저녁먹기");
  }

  private static Routine routineWithReward(String rewardText) {
    Routine routine = new Routine();
    routine.setRewardText(rewardText);
    return routine;
  }

  static Stream<Arguments> profileScopedCalls() {
    return Stream.of(
      Arguments.of("getMyRoutines", ProfileAction.VIEW, (Consumer<RoutineService>) s -> s.getMyRoutines(GUARDIAN)),
      Arguments.of("getTodayRoutines", ProfileAction.VIEW, (Consumer<RoutineService>) s -> s.getTodayRoutines(GUARDIAN)),
      Arguments.of("getPastRoutines", ProfileAction.VIEW, (Consumer<RoutineService>) s -> s.getPastRoutines(GUARDIAN)),
      Arguments.of("getDraftRoutines", ProfileAction.VIEW, (Consumer<RoutineService>) s -> s.getDraftRoutines(GUARDIAN)),
      Arguments.of("getRecentRewards", ProfileAction.VIEW, (Consumer<RoutineService>) s -> s.getRecentRewards(GUARDIAN)),
      Arguments.of("generateQuestion", ProfileAction.MANAGE,
        (Consumer<RoutineService>) s -> s.generateQuestion(GUARDIAN, new RoutineQuestionRequest("내일 병원 가기"))),
      Arguments.of("reorder", ProfileAction.MANAGE, (Consumer<RoutineService>) s -> s.reorder(GUARDIAN, List.of("r-a"))),
      Arguments.of("create", ProfileAction.MANAGE,
        (Consumer<RoutineService>) s -> s.create(GUARDIAN, new RoutineCreateRequest("내일 병원 가기", null, null, null, null)))
    );
  }

  @ParameterizedTest(name = "{0} → {1}")
  @MethodSource("profileScopedCalls")
  @DisplayName("이룸이 단위 API마다 권한 표의 알맞은 칸을 묻는다 — 보기는 VIEW, 만들고 바꾸는 것은 MANAGE")
  void profileScopedCalls_askTheirPermission(String name, ProfileAction expected, Consumer<RoutineService> call) {
    when(profileAccessGuard.profileFor(any(), any())).thenThrow(new CustomException(ErrorCode.PROFILE_ACCESS_DENIED));

    assertThatThrownBy(() -> call.accept(routineService))
      .isInstanceOf(CustomException.class)
      .hasFieldOrPropertyWithValue("errorCode", ErrorCode.PROFILE_ACCESS_DENIED);
    verify(profileAccessGuard).profileFor(GUARDIAN, expected);
    // 판단 전에 AI 를 부르지 않는다 — 거절될 요청에 돈을 쓰지 않는다
    verifyNoInteractions(routineAiPipeline);
  }

  static Stream<Arguments> routineCalls() {
    return Stream.of(
      Arguments.of("confirm", RoutineAction.EDIT, (Consumer<RoutineService>) s -> s.confirm(GUARDIAN, "routine-1")),
      Arguments.of("updateReward", RoutineAction.EDIT,
        (Consumer<RoutineService>) s -> s.updateReward(GUARDIAN, "routine-1", new RewardUpdateRequest("젤리", null))),
      Arguments.of("delete", RoutineAction.EDIT, (Consumer<RoutineService>) s -> s.delete(GUARDIAN, "routine-1")),
      Arguments.of("updateStep", RoutineAction.EDIT,
        (Consumer<RoutineService>) s -> s.updateStep(GUARDIAN, "routine-1", "step-1", new RoutineStepUpdateRequest("제목", null, null))),
      Arguments.of("deleteStep", RoutineAction.EDIT, (Consumer<RoutineService>) s -> s.deleteStep(GUARDIAN, "routine-1", "step-1")),
      Arguments.of("addStep", RoutineAction.EDIT,
        (Consumer<RoutineService>) s -> s.addStep(GUARDIAN, "routine-1", new RoutineStepCreateRequest("제목", "설명"))),
      Arguments.of("reorderSteps", RoutineAction.EDIT,
        (Consumer<RoutineService>) s -> s.reorderSteps(GUARDIAN, "routine-1", List.of("step-2", "step-1"))),
      Arguments.of("completeStep", RoutineAction.PROGRESS, (Consumer<RoutineService>) s -> s.completeStep(GUARDIAN, "routine-1", "step-1")),
      Arguments.of("cancelStep", RoutineAction.PROGRESS, (Consumer<RoutineService>) s -> s.cancelStep(GUARDIAN, "routine-1", "step-1")),
      Arguments.of("syncProgress", RoutineAction.PROGRESS,
        (Consumer<RoutineService>) s -> s.syncProgress(GUARDIAN, "routine-1", List.of("step-1"))),
      Arguments.of("getRoutine", RoutineAction.VIEW, (Consumer<RoutineService>) s -> s.getRoutine(GUARDIAN, "routine-1")),
      Arguments.of("getStepImage", RoutineAction.VIEW, (Consumer<RoutineService>) s -> s.getStepImage(GUARDIAN, "routine-1", "step-1")),
      Arguments.of("duplicate", RoutineAction.COPY, (Consumer<RoutineService>) s -> s.duplicate(GUARDIAN, "routine-1"))
    );
  }

  @ParameterizedTest(name = "{0} → {1}")
  @MethodSource("routineCalls")
  @DisplayName("E30 일과 API마다 권한 표의 알맞은 칸을 묻고, 거절되면 아무것도 바꾸지 않는다")
  void e30_routineCalls_askTheirPermissionFirst(String name, RoutineAction expected, Consumer<RoutineService> call) {
    Routine routine = confirmedRoutine(profileWithStars(0), 2);
    routine.setCreatedBy("member-1");
    when(routineRepository.findById("routine-1")).thenReturn(Optional.of(routine));
    doThrow(new CustomException(ErrorCode.ROUTINE_NOT_CREATOR))
      .when(profileAccessGuard).checkRoutine(any(), any(), any(), any());

    assertThatThrownBy(() -> call.accept(routineService))
      .isInstanceOf(CustomException.class)
      .hasFieldOrPropertyWithValue("errorCode", ErrorCode.ROUTINE_NOT_CREATOR);
    verify(profileAccessGuard).checkRoutine(GUARDIAN, "profile-1", "member-1", expected);
    assertThat(routine.getSteps()).extracting(RoutineStep::getCompleted).containsOnly(false);
    assertThat(routine.getStatus()).isEqualTo(RoutineStatus.CONFIRMED);
    verify(routineRepository, never()).save(any());
  }

  @Test
  @DisplayName("E11 나간 보호자의 일과를 이룸이 폰이 이어서 부르면 404 — 앱은 목록을 다시 받는다")
  void e11_routineRemovedByLeave_elumiGetsNotFound() {
    when(routineRepository.findById("routine-1")).thenReturn(Optional.empty());

    assertThatThrownBy(() -> routineService.completeStep(Caller.elumi("member-1", "l1"), "routine-1", "step-1"))
      .isInstanceOf(CustomException.class)
      .hasFieldOrPropertyWithValue("errorCode", ErrorCode.ROUTINE_NOT_FOUND);
    verifyNoInteractions(profileAccessGuard);
  }

  @Test
  @DisplayName("복제한 일과는 복제한 사람이 만든 것이다 — 원본을 누가 만들었든")
  void duplicate_recordsCallerAsCreator() {
    Routine origin = confirmedRoutine(profileWithStars(0), 1);
    origin.setTitle("병원 다녀오기");
    origin.setCreatedBy("someone-else");
    when(routineRepository.findById("routine-1")).thenReturn(Optional.of(origin));
    ArgumentCaptor<Routine> saved = ArgumentCaptor.forClass(Routine.class);
    when(routineRepository.save(saved.capture())).thenAnswer(i -> i.getArgument(0));

    routineService.duplicate(GUARDIAN, "routine-1");

    assertThat(saved.getValue().getCreatedBy()).isEqualTo("member-1");
  }

  @Test
  @DisplayName("새로 만든 일과에는 만든 사람이 늘 채워진다 — 비어 있으면 아무도 고치지 못한다")
  void create_recordsCallerAsCreator() {
    Profile profile = profileWithNickname("하늘이");
    stubCreatePipeline(profile);
    ArgumentCaptor<Routine> saved = ArgumentCaptor.forClass(Routine.class);
    when(routineRepository.save(saved.capture())).thenAnswer(i -> i.getArgument(0));

    routineService.create(GUARDIAN, new RoutineCreateRequest("내일 병원 가기", null, null, null, null));

    assertThat(saved.getValue().getCreatedBy()).isEqualTo("member-1");
  }
}
