package com.chuseok22.elumserver.routine.application.service;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.assertj.core.api.Assertions.tuple;
import static org.mockito.Mockito.any;
import static org.mockito.Mockito.doThrow;
import static org.mockito.Mockito.eq;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.verifyNoInteractions;
import static org.mockito.Mockito.when;

import com.chuseok22.elumserver.ai.application.service.SensitiveInfoGuardService;
import com.chuseok22.elumserver.ai.core.SensitiveInfoCheckResult;
import com.chuseok22.elumserver.common.infrastructure.exception.CustomException;
import com.chuseok22.elumserver.common.infrastructure.exception.ErrorCode;
import com.chuseok22.elumserver.member.infrastructure.entity.CharacterType;
import com.chuseok22.elumserver.member.infrastructure.entity.Member;
import com.chuseok22.elumserver.member.infrastructure.entity.SupportGoal;
import com.chuseok22.elumserver.member.infrastructure.repository.MemberRepository;
import com.chuseok22.elumserver.routine.application.dto.request.RoutineCreateRequest;
import com.chuseok22.elumserver.routine.application.dto.request.RoutineQuestionRequest;
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
import java.util.List;
import java.util.Optional;
import java.util.Set;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.InjectMocks;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;

@ExtendWith(MockitoExtension.class)
class RoutineServiceTest {

  @Mock
  private RoutineRepository routineRepository;

  @Mock
  private RoutineImageStorage routineImageStorage;

  @Mock
  private MemberRepository memberRepository;

  @Mock
  private SensitiveInfoGuardService sensitiveInfoGuardService;

  @Mock
  private RoutineAiPipeline routineAiPipeline;

  @Mock
  private RoutineRequestCooldownGuard routineRequestCooldownGuard;

  @InjectMocks
  private RoutineService routineService;

  @Test
  @DisplayName("본인 소유 일과의 단계 이미지를 조회하면 저장된 이미지 내용을 반환한다")
  void getStepImage_ownedRoutine_returnsImageContent() {
    Member member = new Member();
    member.setId("member-1");
    Routine routine = new Routine();
    routine.setMember(member);
    RoutineStep step = new RoutineStep();
    step.setId("step-1");
    step.setImagePath("data/routine-images/batch-1/1.png");
    routine.setSteps(List.of(step));
    when(routineRepository.findById("routine-1")).thenReturn(Optional.of(routine));
    RoutineImageStorage.ImageContent expected =
      new RoutineImageStorage.ImageContent(new byte[]{1, 2, 3}, "image/png");
    when(routineImageStorage.read("data/routine-images/batch-1/1.png")).thenReturn(expected);

    RoutineImageStorage.ImageContent result = routineService.getStepImage("member-1", "routine-1", "step-1");

    assertThat(result).isEqualTo(expected);
  }

  @Test
  @DisplayName("다른 회원의 일과에 접근하면 ROUTINE_ACCESS_DENIED를 던진다")
  void getStepImage_notOwner_throwsAccessDenied() {
    Member member = new Member();
    member.setId("member-1");
    Routine routine = new Routine();
    routine.setMember(member);
    when(routineRepository.findById("routine-1")).thenReturn(Optional.of(routine));

    assertThatThrownBy(() -> routineService.getStepImage("member-2", "routine-1", "step-1"))
      .isInstanceOf(CustomException.class)
      .satisfies(e -> assertThat(((CustomException) e).getErrorCode())
        .isEqualTo(ErrorCode.ROUTINE_ACCESS_DENIED));
  }

  @Test
  @DisplayName("존재하지 않는 단계를 조회하면 ROUTINE_STEP_NOT_FOUND를 던진다")
  void getStepImage_missingStep_throwsStepNotFound() {
    Member member = new Member();
    member.setId("member-1");
    Routine routine = new Routine();
    routine.setMember(member);
    routine.setSteps(List.of());
    when(routineRepository.findById("routine-1")).thenReturn(Optional.of(routine));

    assertThatThrownBy(() -> routineService.getStepImage("member-1", "routine-1", "missing-step"))
      .isInstanceOf(CustomException.class)
      .satisfies(e -> assertThat(((CustomException) e).getErrorCode())
        .isEqualTo(ErrorCode.ROUTINE_STEP_NOT_FOUND));
  }

  @Test
  @DisplayName("선택한 도움 목표가 없으면 질문 없이 required:false를 반환한다")
  void generateQuestion_noRelevantGoals_returnsNotRequired() {
    Member member = new Member();
    member.setId("member-1");
    member.setSupportGoals(Set.of(SupportGoal.STEP_BY_STEP));
    when(memberRepository.findById("member-1")).thenReturn(Optional.of(member));

    RoutineQuestionResponse response =
      routineService.generateQuestion("member-1", new RoutineQuestionRequest("내일 병원 가기"));

    assertThat(response.required()).isFalse();
    assertThat(response.questions()).isEmpty();
  }

  @Test
  @DisplayName("PREPARE_ITEMS를 선택했으면 AI 파이프라인 결과를 emoji/label 옵션으로 변환해 반환한다")
  void generateQuestion_relevantGoal_returnsQuestions() {
    Member member = new Member();
    member.setId("member-1");
    member.setNickname("하늘이");
    member.setSupportGoals(Set.of(SupportGoal.PREPARE_ITEMS));
    when(memberRepository.findById("member-1")).thenReturn(Optional.of(member));
    when(sensitiveInfoGuardService.check("내일 비 오는 날 학교 가기"))
      .thenReturn(new SensitiveInfoCheckResult(true, false, List.of(), "내일 비 오는 날 학교 가기"));
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
      routineService.generateQuestion("member-1", new RoutineQuestionRequest("내일 비 오는 날 학교 가기"));

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

    assertThatThrownBy(() -> routineService.create("member-1", new RoutineCreateRequest(null, null, null)))
      .isInstanceOf(CustomException.class)
      .satisfies(e -> assertThat(((CustomException) e).getErrorCode())
        .isEqualTo(ErrorCode.ROUTINE_REQUEST_TOO_FREQUENT));
    verifyNoInteractions(memberRepository, routineAiPipeline);
  }

  @Test
  @DisplayName("일과 생성 시 회원이 설정한 캐릭터를 AI 파이프라인 생성 호출에 그대로 전달한다")
  void create_withMemberCharacter_passesCharacterToPipeline() {
    Member member = new Member();
    member.setId("member-1");
    member.setNickname("하늘이");
    member.setSupportGoals(Set.of());
    member.setCharacter(CharacterType.LULU);
    when(memberRepository.findById("member-1")).thenReturn(Optional.of(member));
    when(sensitiveInfoGuardService.check("내일 병원 가기"))
      .thenReturn(new SensitiveInfoCheckResult(true, false, List.of(), "내일 병원 가기"));
    RoutineAiPipeline.RoutineGenerationResult generationResult = new RoutineAiPipeline.RoutineGenerationResult(
      "병원 다녀오기",
      List.of(new RoutineAiPipeline.GeneratedStep(1, "신발 신어요", "신발 신기", "data/routine-images/batch-1/1.png"))
    );
    when(routineAiPipeline.generateForCreate(any(), any(), any(), any(), eq(CharacterType.LULU)))
      .thenReturn(generationResult);
    when(routineRepository.save(any())).thenAnswer(invocation -> invocation.getArgument(0));

    routineService.create("member-1", new RoutineCreateRequest("내일 병원 가기", null, null));

    verify(routineAiPipeline).generateForCreate(
      eq("내일 병원 가기"), eq("하늘이"), eq(Set.of()), eq(List.of()), eq(CharacterType.LULU)
    );
  }

  @Test
  @DisplayName("오늘 일과를 조회하면 CONFIRMED/COMPLETED 상태의 오늘 범위 일과만 반환한다")
  void getTodayRoutines_returnsConfirmedAndCompletedRoutinesForToday() {
    Member member = new Member();
    member.setId("member-1");
    Routine routine = new Routine();
    routine.setId("routine-1");
    routine.setTitle("병원 다녀오기");
    routine.setMember(member);
    routine.setStatus(RoutineStatus.CONFIRMED);
    routine.setSteps(List.of());
    when(routineRepository.findAllByMemberIdAndStatusInAndScheduledAtBetweenOrderByScheduledAtAsc(
      eq("member-1"), eq(List.of(RoutineStatus.CONFIRMED, RoutineStatus.COMPLETED)), any(), any()
    )).thenReturn(List.of(routine));

    List<RoutineResponse> result = routineService.getTodayRoutines("member-1");

    assertThat(result).hasSize(1);
    assertThat(result.get(0).id()).isEqualTo("routine-1");
    verify(routineRepository).findAllByMemberIdAndStatusInAndScheduledAtBetweenOrderByScheduledAtAsc(
      eq("member-1"), eq(List.of(RoutineStatus.CONFIRMED, RoutineStatus.COMPLETED)), any(), any()
    );
  }

  // --- 오프라인 퍼스트 일괄 반영 (이슈 #140) ---

  private Routine confirmedRoutine(Member member, int stepCount) {
    Routine routine = new Routine();
    routine.setId("routine-1");
    routine.setMember(member);
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

  private Member memberWithStars(int stars) {
    Member member = new Member();
    member.setId("member-1");
    member.setTotalStars(stars);
    return member;
  }

  @Test
  @DisplayName("syncProgress: 부분 집합을 보내면 해당 단계만 완료되고 별은 늘어난 수만큼 오른다")
  void syncProgress_partialSet_marksOnlyThoseAndAddsStars() {
    Member member = memberWithStars(0);
    Routine routine = confirmedRoutine(member, 3);
    when(routineRepository.findById("routine-1")).thenReturn(Optional.of(routine));

    RoutineResponse response = routineService.syncProgress("member-1", "routine-1", List.of("step-1", "step-2"));

    assertThat(routine.getSteps()).extracting(RoutineStep::getCompleted).containsExactly(true, true, false);
    assertThat(routine.getSteps().get(0).getCompletedAt()).isNotNull();
    assertThat(routine.getSteps().get(2).getCompletedAt()).isNull();
    assertThat(member.getTotalStars()).isEqualTo(2);
    assertThat(routine.getStatus()).isEqualTo(RoutineStatus.CONFIRMED);
    assertThat(response.progressPercent()).isEqualTo(66);
  }

  @Test
  @DisplayName("syncProgress: 전부 보내면 COMPLETED가 되고 completedAt이 찍힌다")
  void syncProgress_allSteps_completesRoutine() {
    Routine routine = confirmedRoutine(memberWithStars(0), 2);
    when(routineRepository.findById("routine-1")).thenReturn(Optional.of(routine));

    routineService.syncProgress("member-1", "routine-1", List.of("step-1", "step-2"));

    assertThat(routine.getStatus()).isEqualTo(RoutineStatus.COMPLETED);
    assertThat(routine.getCompletedAt()).isNotNull();
  }

  @Test
  @DisplayName("syncProgress: 완료였던 단계를 집합에서 빼면 해제되고 별이 그만큼 내려가며 CONFIRMED로 돌아온다")
  void syncProgress_removingSteps_uncompletesAndSubtractsStars() {
    Member member = memberWithStars(3);
    Routine routine = confirmedRoutine(member, 3);
    routine.getSteps().forEach(step -> {
      step.setCompleted(true);
      step.setCompletedAt(java.time.LocalDateTime.now());
    });
    routine.setStatus(RoutineStatus.COMPLETED);
    routine.setCompletedAt(java.time.LocalDateTime.now());
    when(routineRepository.findById("routine-1")).thenReturn(Optional.of(routine));

    routineService.syncProgress("member-1", "routine-1", List.of("step-1"));

    assertThat(routine.getSteps()).extracting(RoutineStep::getCompleted).containsExactly(true, false, false);
    assertThat(routine.getSteps().get(1).getCompletedAt()).isNull();
    assertThat(member.getTotalStars()).isEqualTo(1);
    assertThat(routine.getStatus()).isEqualTo(RoutineStatus.CONFIRMED);
    assertThat(routine.getCompletedAt()).isNull();
  }

  @Test
  @DisplayName("syncProgress: 같은 집합을 두 번 보내도 별이 더 오르지 않는다 (멱등)")
  void syncProgress_sameSetTwice_isIdempotent() {
    Member member = memberWithStars(0);
    Routine routine = confirmedRoutine(member, 2);
    when(routineRepository.findById("routine-1")).thenReturn(Optional.of(routine));

    routineService.syncProgress("member-1", "routine-1", List.of("step-1"));
    routineService.syncProgress("member-1", "routine-1", List.of("step-1"));

    assertThat(member.getTotalStars()).isEqualTo(1);
  }

  @Test
  @DisplayName("syncProgress: 순서를 건너뛴 집합도 그대로 받아들인다")
  void syncProgress_outOfOrderSet_isAccepted() {
    Routine routine = confirmedRoutine(memberWithStars(0), 3);
    when(routineRepository.findById("routine-1")).thenReturn(Optional.of(routine));

    routineService.syncProgress("member-1", "routine-1", List.of("step-3"));

    assertThat(routine.getSteps()).extracting(RoutineStep::getCompleted).containsExactly(false, false, true);
  }

  @Test
  @DisplayName("syncProgress: 별이 0인 상태에서 해제 요청이 와도 음수가 되지 않는다")
  void syncProgress_neverGoesBelowZeroStars() {
    Member member = memberWithStars(0);
    Routine routine = confirmedRoutine(member, 1);
    routine.getSteps().get(0).setCompleted(true);
    when(routineRepository.findById("routine-1")).thenReturn(Optional.of(routine));

    routineService.syncProgress("member-1", "routine-1", List.of());

    assertThat(member.getTotalStars()).isZero();
  }

  @Test
  @DisplayName("syncProgress: 승인 전 일과면 ROUTINE_INVALID_STATUS를 던진다")
  void syncProgress_pendingReview_throws() {
    Routine routine = confirmedRoutine(memberWithStars(0), 1);
    routine.setStatus(RoutineStatus.PENDING_REVIEW);
    when(routineRepository.findById("routine-1")).thenReturn(Optional.of(routine));

    assertThatThrownBy(() -> routineService.syncProgress("member-1", "routine-1", List.of("step-1")))
      .isInstanceOf(CustomException.class)
      .satisfies(e -> assertThat(((CustomException) e).getErrorCode()).isEqualTo(ErrorCode.ROUTINE_INVALID_STATUS));
  }

  @Test
  @DisplayName("syncProgress: 이 일과에 없는 단계 id가 섞이면 ROUTINE_STEP_NOT_FOUND를 던진다")
  void syncProgress_unknownStepId_throws() {
    Routine routine = confirmedRoutine(memberWithStars(0), 1);
    when(routineRepository.findById("routine-1")).thenReturn(Optional.of(routine));

    assertThatThrownBy(() -> routineService.syncProgress("member-1", "routine-1", List.of("step-1", "ghost")))
      .isInstanceOf(CustomException.class)
      .satisfies(e -> assertThat(((CustomException) e).getErrorCode()).isEqualTo(ErrorCode.ROUTINE_STEP_NOT_FOUND));
  }
}
