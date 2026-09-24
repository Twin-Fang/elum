package com.chuseok22.elumserver.routine.application.service;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyBoolean;
import static org.mockito.ArgumentMatchers.anyInt;
import static org.mockito.ArgumentMatchers.anyString;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.doThrow;
import static org.mockito.Mockito.inOrder;
import static org.mockito.Mockito.lenient;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.verifyNoInteractions;
import static org.mockito.Mockito.when;

import com.chuseok22.elumserver.ai.core.AiCallContext;
import com.chuseok22.elumserver.common.infrastructure.exception.CustomException;
import com.chuseok22.elumserver.common.infrastructure.exception.ErrorCode;
import com.chuseok22.elumserver.credit.application.service.CreditQueryService;
import com.chuseok22.elumserver.credit.application.service.CreditReservation;
import com.chuseok22.elumserver.credit.application.service.CreditReservationService;
import com.chuseok22.elumserver.credit.application.service.CreditSettlement;
import com.chuseok22.elumserver.credit.core.CreditJobKind;
import com.chuseok22.elumserver.member.application.service.Caller;
import com.chuseok22.elumserver.member.application.service.ProfileAccessGuard;
import com.chuseok22.elumserver.member.application.service.ProfileAccessGuard.ProfileAction;
import com.chuseok22.elumserver.member.infrastructure.entity.CharacterType;
import com.chuseok22.elumserver.member.infrastructure.entity.Profile;
import com.chuseok22.elumserver.member.infrastructure.entity.SupportGoal;
import com.chuseok22.elumserver.member.infrastructure.repository.ProfileRepository;
import com.chuseok22.elumserver.routine.application.dto.request.RoutineCreateRequest;
import com.chuseok22.elumserver.routine.application.dto.request.RoutineQuestionRequest;
import com.chuseok22.elumserver.routine.application.dto.response.RoutineResponse;
import com.chuseok22.elumserver.routine.infrastructure.ai.RoutineAiPipeline;
import com.chuseok22.elumserver.routine.infrastructure.entity.Routine;
import com.chuseok22.elumserver.routine.infrastructure.guard.RoutineRequestCooldownGuard;
import com.chuseok22.elumserver.routine.infrastructure.repository.RoutineRepository;
import com.chuseok22.elumserver.routine.infrastructure.repository.RoutineStepRepository;
import com.chuseok22.elumserver.routine.infrastructure.storage.RoutineImageStorage;
import java.util.List;
import java.util.Optional;
import java.util.Set;
import java.util.concurrent.atomic.AtomicReference;
import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.ArgumentCaptor;
import org.mockito.InOrder;
import org.mockito.InjectMocks;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;

/**
 * 일과 생성 · 추가 질문의 크레딧 연결 (#407 Task S3).
 *
 * <p>AI 는 부르지 않는다 — 파이프라인은 목이다. 장부 계산은 CreditReservationServiceTest 가 본다. 여기서는
 * "언제 예약·정산·반환을 부르는가"와 "멱등 키로 다시 오면 AI 를 다시 부르지 않는가"를 본다.
 */
@ExtendWith(MockitoExtension.class)
class RoutineServiceCreditTest {

  private static final Caller GUARDIAN = Caller.guardian("member-1");
  private static final RoutineCreateRequest REQUEST =
    new RoutineCreateRequest("내일 병원 가기", null, null, null, null);

  @Mock private RoutineRepository routineRepository;
  @Mock private ProfileRepository profileRepository;
  @Mock private RoutineAiPipeline routineAiPipeline;
  @Mock private RoutineImageStorage routineImageStorage;
  @Mock private RoutineRequestCooldownGuard routineRequestCooldownGuard;
  @Mock private RoutineQuotaGuard routineQuotaGuard;
  @Mock private AiDailyBudgetGuard aiDailyBudgetGuard;
  @Mock private RoutineStepImageFiller routineStepImageFiller;
  @Mock private ProfileAccessGuard profileAccessGuard;
  @Mock private RoutineCreationWriter routineCreationWriter;
  @Mock private RoutineStepRepository routineStepRepository;
  @Mock private CreditReservationService creditReservationService;
  @Mock private CreditQueryService creditQueryService;

  @InjectMocks private RoutineService routineService;

  @AfterEach
  void tearDown() {
    AiCallContext.clear();
  }

  private Profile profile() {
    Profile profile = new Profile();
    profile.setId("profile-1");
    profile.setNickname("하늘이");
    profile.setCharacter(CharacterType.LULU);
    profile.setSupportGoals(Set.of());
    when(profileAccessGuard.profileFor(eq(GUARDIAN), any(ProfileAction.class))).thenReturn(profile);
    return profile;
  }

  /// 카드 3장 중 2장에만 그림이 붙은 생성 결과.
  private void stubPipeline() {
    when(routineAiPipeline.generateForCreate(any(), any(), any(), any(), any(), any()))
      .thenReturn(new RoutineAiPipeline.RoutineGenerationResult("병원 다녀오기", List.of(
        new RoutineAiPipeline.GeneratedStep(1, "신발 신어요", "신발", "img/b/1.png"),
        new RoutineAiPipeline.GeneratedStep(2, "차 타요", "차", null),
        new RoutineAiPipeline.GeneratedStep(3, "진료 받아요", "진료", "img/b/3.png")
      ), "batch-1"));
  }

  private void reserved(String key) {
    when(creditReservationService.reserve("member-1", CreditJobKind.ROUTINE_CREATE, key, true))
      .thenReturn(CreditReservation.reserved("job-1"));
  }

  @Test
  @DisplayName("성공하면 붙은 그림 수로 저장 트랜잭션에서 정산하고 응답에 크레딧 사용을 싣는다")
  void create_success_settlesInWriterAndReturnsCredit() {
    profile();
    reserved("key-1");
    stubPipeline();
    when(routineCreationWriter.save(eq("member-1"), eq("profile-1"), any(Routine.class), eq("job-1"), eq(2)))
      .thenAnswer(i -> new RoutineCreationWriter.SavedRoutine(i.getArgument(2), new CreditSettlement(3, 0, 97)));

    RoutineResponse response = routineService.create(GUARDIAN, REQUEST, "key-1");

    // 그림 수 = imagePath 가 있는 카드만 — 실패해 비어 있는 카드는 청구하지 않는다
    assertThat(response.credit()).isEqualTo(new RoutineResponse.CreditUsage(3, 2, 3, 97));
    verify(creditReservationService, never()).release(anyString(), anyString());
  }

  @Test
  @DisplayName("잔액 1 · 그림 8장이어도 일과는 저장되고 응답은 차감 1 · 잔액 0 이다 (Review Focus 1)")
  void create_lowBalance_routineStillSavedWithOverage() {
    profile();
    reserved("key-1");
    stubPipeline();
    when(routineCreationWriter.save(any(), any(), any(), eq("job-1"), anyInt()))
      .thenAnswer(i -> new RoutineCreationWriter.SavedRoutine(i.getArgument(2), new CreditSettlement(1, 2, 0)));

    RoutineResponse response = routineService.create(GUARDIAN, REQUEST, "key-1");

    assertThat(response.id()).isNull(); // 목 저장이라 id 는 없다 — 일과 자체는 돌아왔다
    assertThat(response.steps()).hasSize(3);
    assertThat(response.credit().charged()).isEqualTo(1);
    assertThat(response.credit().balanceAfter()).isZero();
  }

  @Test
  @DisplayName("같은 멱등 키가 이미 끝났으면 AI 를 다시 부르지 않고 저장된 일과를 돌려준다 (Review Focus 2)")
  void create_alreadySettled_returnsSavedWithoutCallingAi() {
    profile();
    when(creditReservationService.reserve("member-1", CreditJobKind.ROUTINE_CREATE, "key-1", true))
      .thenReturn(CreditReservation.alreadySettled("job-1", "routine-9"));
    RoutineResponse saved = RoutineResponse.from(routine("routine-9"));
    when(routineCreationWriter.loadSaved(GUARDIAN, "routine-9")).thenReturn(saved);

    RoutineResponse response = routineService.create(GUARDIAN, REQUEST, "key-1");

    assertThat(response).isSameAs(saved);
    verifyNoInteractions(routineAiPipeline, routineImageStorage);
    verify(routineCreationWriter, never()).save(any(), any(), any(), any(), anyInt());
  }

  @Test
  @DisplayName("같은 키가 이미 끝났으면 이번 주 한도를 넘었어도 저장된 일과를 돌려준다 — 한도·예산을 보기 전에 찾는다")
  void create_settledKey_bypassesQuotaAndBudget() {
    when(creditReservationService.findSettledRoutineId("member-1", "key-1")).thenReturn(Optional.of("routine-9"));
    lenient().doThrow(new CustomException(ErrorCode.ROUTINE_CREATE_LIMIT_EXCEEDED)).when(routineQuotaGuard).guard("member-1");
    RoutineResponse saved = RoutineResponse.from(routine("routine-9"));
    when(routineCreationWriter.loadSaved(GUARDIAN, "routine-9")).thenReturn(saved);

    RoutineResponse response = routineService.create(GUARDIAN, REQUEST, "key-1");

    assertThat(response).isSameAs(saved);
    verify(routineQuotaGuard, never()).guard(anyString());
    verify(aiDailyBudgetGuard, never()).guard();
    verify(creditReservationService, never()).reserve(anyString(), any(), anyString(), anyBoolean());
    verifyNoInteractions(routineAiPipeline);
  }

  @Test
  @DisplayName("같은 키가 이미 끝났으면 쿨다운 안이어도 저장된 일과를 돌려준다 — 응답 유실 재전송을 막지 않는다")
  void create_settledKey_bypassesCooldown() {
    when(creditReservationService.findSettledRoutineId("member-1", "key-1")).thenReturn(Optional.of("routine-9"));
    lenient().doThrow(new CustomException(ErrorCode.ROUTINE_REQUEST_TOO_FREQUENT))
      .when(routineRequestCooldownGuard).guard("member-1");
    RoutineResponse saved = RoutineResponse.from(routine("routine-9"));
    when(routineCreationWriter.loadSaved(GUARDIAN, "routine-9")).thenReturn(saved);

    RoutineResponse response = routineService.create(GUARDIAN, REQUEST, "key-1");

    assertThat(response).isSameAs(saved);
    verify(routineRequestCooldownGuard, never()).guard(anyString());
    verifyNoInteractions(routineAiPipeline);
  }

  @Test
  @DisplayName("같은 키로 다시 왔는데 그 사이 이룸이에서 나갔으면 저장된 일과를 주지 않는다")
  void create_settledKey_guardianLeft_denied() {
    when(creditReservationService.findSettledRoutineId("member-1", "key-1")).thenReturn(Optional.of("routine-9"));
    when(routineCreationWriter.loadSaved(GUARDIAN, "routine-9"))
      .thenThrow(new CustomException(ErrorCode.ROUTINE_ACCESS_DENIED));

    assertThatThrownBy(() -> routineService.create(GUARDIAN, REQUEST, "key-1"))
      .hasFieldOrPropertyWithValue("errorCode", ErrorCode.ROUTINE_ACCESS_DENIED);
    verifyNoInteractions(routineAiPipeline);
  }

  @Test
  @DisplayName("멱등 키가 없으면(구버전 앱) 끝난 작업을 찾지 않는다 — 서버가 만든 새 키는 찾을 것이 없다")
  void create_noKey_skipsSettledLookup() {
    profile();
    when(creditReservationService.reserve(anyString(), any(), anyString(), eq(true)))
      .thenThrow(new CustomException(ErrorCode.AI_CREDIT_INSUFFICIENT));

    assertThatThrownBy(() -> routineService.create(GUARDIAN, REQUEST, null))
      .hasFieldOrPropertyWithValue("errorCode", ErrorCode.AI_CREDIT_INSUFFICIENT);
    verify(creditReservationService, never()).findSettledRoutineId(anyString(), anyString());
  }

  @Test
  @DisplayName("같은 키가 아직 만드는 중이면 409 — AI 를 부르지 않는다")
  void create_inProgress_conflictWithoutCallingAi() {
    profile();
    when(creditReservationService.reserve(anyString(), any(), anyString(), eq(true)))
      .thenThrow(new CustomException(ErrorCode.AI_CREDIT_JOB_IN_PROGRESS));

    assertThatThrownBy(() -> routineService.create(GUARDIAN, REQUEST, "key-1"))
      .hasFieldOrPropertyWithValue("errorCode", ErrorCode.AI_CREDIT_JOB_IN_PROGRESS);
    verifyNoInteractions(routineAiPipeline);
  }

  @Test
  @DisplayName("크레딧이 모자라면 403 — AI 를 부르지 않는다")
  void create_insufficient_rejectsWithoutCallingAi() {
    profile();
    when(creditReservationService.reserve(anyString(), any(), anyString(), eq(true)))
      .thenThrow(new CustomException(ErrorCode.AI_CREDIT_INSUFFICIENT));

    assertThatThrownBy(() -> routineService.create(GUARDIAN, REQUEST, "key-1"))
      .hasFieldOrPropertyWithValue("errorCode", ErrorCode.AI_CREDIT_INSUFFICIENT);
    verifyNoInteractions(routineAiPipeline);
  }

  @Test
  @DisplayName("저장이 실패하면 그림을 지우고 예약을 반환하고 원래 예외를 그대로 낸다 (Review Focus 3)")
  void create_saveFails_releasesAndCleansUp() {
    profile();
    reserved("key-1");
    stubPipeline();
    when(routineCreationWriter.save(any(), any(), any(), eq("job-1"), anyInt()))
      .thenThrow(new CustomException(ErrorCode.PROFILE_ACCESS_DENIED));

    assertThatThrownBy(() -> routineService.create(GUARDIAN, REQUEST, "key-1"))
      .hasFieldOrPropertyWithValue("errorCode", ErrorCode.PROFILE_ACCESS_DENIED);

    verify(routineImageStorage).deleteBatch("batch-1");
    ArgumentCaptor<String> reason = ArgumentCaptor.forClass(String.class);
    verify(creditReservationService).release(eq("job-1"), reason.capture());
    assertThat(reason.getValue()).contains("PROFILE_ACCESS_DENIED");
  }

  @Test
  @DisplayName("AI 생성이 실패하면 예약을 반환한다 — 만들지 못한 일과는 청구하지 않는다")
  void create_aiFails_releases() {
    profile();
    reserved("key-1");
    when(routineAiPipeline.generateForCreate(any(), any(), any(), any(), any(), any()))
      .thenThrow(new CustomException(ErrorCode.ROUTINE_AI_GENERATION_FAILED));

    assertThatThrownBy(() -> routineService.create(GUARDIAN, REQUEST, "key-1"))
      .hasFieldOrPropertyWithValue("errorCode", ErrorCode.ROUTINE_AI_GENERATION_FAILED);
    verify(creditReservationService).release(eq("job-1"), anyString());
    verify(routineCreationWriter, never()).save(any(), any(), any(), any(), anyInt());
  }

  @Test
  @DisplayName("AI 호출 맥락에 작업 id 를 싣고 끝나면 비운다 — 호출 기록이 작업에 이어진다")
  void create_setsCreditJobIdOnAiContext() {
    profile();
    reserved("key-1");
    AtomicReference<String> seen = new AtomicReference<>();
    when(routineAiPipeline.generateForCreate(any(), any(), any(), any(), any(), any())).thenAnswer(i -> {
      seen.set(AiCallContext.currentCreditJobId());
      return new RoutineAiPipeline.RoutineGenerationResult("t", List.of(
        new RoutineAiPipeline.GeneratedStep(1, "d", "t", null)), "batch-1");
    });
    when(routineCreationWriter.save(any(), any(), any(), any(), anyInt()))
      .thenAnswer(i -> new RoutineCreationWriter.SavedRoutine(i.getArgument(2), new CreditSettlement(1, 0, 99)));

    routineService.create(GUARDIAN, REQUEST, "key-1");

    assertThat(seen.get()).isEqualTo("job-1");
    assertThat(AiCallContext.currentCreditJobId()).isNull();
  }

  @Test
  @DisplayName("크레딧이 꺼져 있으면 정산하지 않고 응답 credit 은 null 이다")
  void create_creditDisabled_noSettlementAndNullCredit() {
    profile();
    when(creditReservationService.reserve(anyString(), any(), anyString(), eq(true)))
      .thenReturn(CreditReservation.disabled());
    stubPipeline();
    when(routineCreationWriter.save(any(), any(), any(), eq(null), anyInt()))
      .thenAnswer(i -> new RoutineCreationWriter.SavedRoutine(i.getArgument(2), null));

    RoutineResponse response = routineService.create(GUARDIAN, REQUEST, "key-1");

    assertThat(response.credit()).isNull();
  }

  @Test
  @DisplayName("멱등 키를 빼면(구버전 앱) 서버가 새 키를 만든다")
  void create_missingKey_serverGeneratesOne() {
    profile();
    ArgumentCaptor<String> key = ArgumentCaptor.forClass(String.class);
    when(creditReservationService.reserve(anyString(), any(), key.capture(), eq(true)))
      .thenReturn(CreditReservation.disabled());
    stubPipeline();
    when(routineCreationWriter.save(any(), any(), any(), any(), anyInt()))
      .thenAnswer(i -> new RoutineCreationWriter.SavedRoutine(i.getArgument(2), null));

    routineService.create(GUARDIAN, REQUEST, "  ");

    assertThat(key.getValue()).isNotBlank().hasSize(36);
  }

  @Test
  @DisplayName("거절 검사는 모두 예약 앞이다 — 쿨다운 → 횟수·보유 → 비용 상한 → 이룸이 접근 → 예약")
  void create_guardsRunBeforeReserve() {
    profile();
    when(creditReservationService.reserve(anyString(), any(), anyString(), eq(true)))
      .thenReturn(CreditReservation.disabled());
    stubPipeline();
    when(routineCreationWriter.save(any(), any(), any(), any(), anyInt()))
      .thenAnswer(i -> new RoutineCreationWriter.SavedRoutine(i.getArgument(2), null));

    routineService.create(GUARDIAN, REQUEST, "key-1");

    InOrder order = inOrder(routineRequestCooldownGuard, routineQuotaGuard, aiDailyBudgetGuard,
      profileAccessGuard, creditReservationService, routineAiPipeline);
    order.verify(routineRequestCooldownGuard).guard("member-1");
    order.verify(routineQuotaGuard).guard("member-1");
    order.verify(aiDailyBudgetGuard).guard();
    order.verify(profileAccessGuard).profileFor(eq(GUARDIAN), any(ProfileAction.class));
    order.verify(creditReservationService).reserve(anyString(), any(), anyString(), eq(true));
    order.verify(routineAiPipeline).generateForCreate(any(), any(), any(), any(), any(), any());
  }

  @Test
  @DisplayName("비용 상한에 걸리면 예약하지 않는다 — 거절에 장부 기록을 남기지 않는다")
  void create_budgetReached_doesNotReserve() {
    doThrow(new CustomException(ErrorCode.AI_DAILY_BUDGET_EXCEEDED)).when(aiDailyBudgetGuard).guard();

    assertThatThrownBy(() -> routineService.create(GUARDIAN, REQUEST, "key-1"))
      .hasFieldOrPropertyWithValue("errorCode", ErrorCode.AI_DAILY_BUDGET_EXCEEDED);
    // 끝난 키 선조회(읽기)는 한도 검사 앞이라 있다. 예약·반환은 없어야 한다.
    verify(creditReservationService, never()).reserve(anyString(), any(), anyString(), anyBoolean());
    verify(creditReservationService, never()).release(anyString(), anyString());
  }

  // --- 추가 질문 ---

  @Test
  @DisplayName("추가 질문: 크레딧이 모자라면 AI 를 부르기 전에 403 을 그대로 낸다")
  void question_insufficient_rejectsBeforeAi() {
    Profile profile = profile();
    profile.setSupportGoals(Set.of(SupportGoal.PREPARE_ITEMS));
    doThrow(new CustomException(ErrorCode.AI_CREDIT_INSUFFICIENT))
      .when(creditQueryService).requireCanStartRoutine("member-1");

    assertThatThrownBy(() -> routineService.generateQuestion(GUARDIAN, new RoutineQuestionRequest("학교 가기")))
      .hasFieldOrPropertyWithValue("errorCode", ErrorCode.AI_CREDIT_INSUFFICIENT);
    verifyNoInteractions(routineAiPipeline);
  }

  @Test
  @DisplayName("추가 질문: 크레딧이 있거나 꺼져 있으면 예전처럼 질문을 만든다")
  void question_allowed_callsAi() {
    Profile profile = profile();
    profile.setSupportGoals(Set.of(SupportGoal.PREPARE_ITEMS));
    when(routineAiPipeline.generateQuestion(any(), any(), any()))
      .thenReturn(new RoutineAiPipeline.RoutineQuestionResult(List.of()));

    routineService.generateQuestion(GUARDIAN, new RoutineQuestionRequest("학교 가기"));

    verify(creditQueryService).requireCanStartRoutine("member-1");
    verify(routineAiPipeline).generateQuestion(any(), any(), any());
  }

  private static Routine routine(String id) {
    Routine routine = new Routine();
    routine.setId(id);
    routine.setTitle("병원 다녀오기");
    routine.setStatus(com.chuseok22.elumserver.routine.infrastructure.entity.RoutineStatus.PENDING_REVIEW);
    routine.setSteps(List.of());
    return routine;
  }
}
