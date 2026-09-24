package com.chuseok22.elumserver.routine.application.service;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyInt;
import static org.mockito.ArgumentMatchers.anyString;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.ArgumentMatchers.startsWith;
import static org.mockito.Mockito.lenient;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.verifyNoInteractions;
import static org.mockito.Mockito.when;

import com.chuseok22.elumserver.ai.application.service.CardImageGenerator;
import com.chuseok22.elumserver.ai.core.AiCallContext;
import com.chuseok22.elumserver.ai.core.GeneratedImage;
import com.chuseok22.elumserver.common.infrastructure.exception.CustomException;
import com.chuseok22.elumserver.common.infrastructure.exception.ErrorCode;
import com.chuseok22.elumserver.common.infrastructure.store.InMemorySharedStateStore;
import com.chuseok22.elumserver.credit.application.service.CreditQueryService;
import com.chuseok22.elumserver.credit.application.service.CreditReservation;
import com.chuseok22.elumserver.credit.application.service.CreditReservationService;
import com.chuseok22.elumserver.credit.core.CreditJobKind;
import com.chuseok22.elumserver.member.application.service.Caller;
import com.chuseok22.elumserver.member.application.service.ProfileAccessGuard;
import com.chuseok22.elumserver.member.infrastructure.entity.CharacterType;
import com.chuseok22.elumserver.member.infrastructure.entity.Member;
import com.chuseok22.elumserver.member.infrastructure.entity.Profile;
import com.chuseok22.elumserver.member.infrastructure.repository.ProfileRepository;
import com.chuseok22.elumserver.routine.application.dto.request.RoutineStepCreateRequest;
import com.chuseok22.elumserver.routine.application.dto.response.RoutineResponse;
import com.chuseok22.elumserver.routine.infrastructure.ai.RoutineAiPipeline;
import com.chuseok22.elumserver.routine.infrastructure.entity.Routine;
import com.chuseok22.elumserver.routine.infrastructure.entity.RoutineStatus;
import com.chuseok22.elumserver.routine.infrastructure.entity.RoutineStep;
import com.chuseok22.elumserver.routine.infrastructure.guard.RoutineRequestCooldownGuard;
import com.chuseok22.elumserver.routine.infrastructure.guard.RoutineStepImageThrottle;
import com.chuseok22.elumserver.routine.infrastructure.repository.RoutineRepository;
import com.chuseok22.elumserver.routine.infrastructure.repository.RoutineStepRepository;
import com.chuseok22.elumserver.routine.infrastructure.storage.RoutineImageStorage;
import java.util.ArrayList;
import java.util.List;
import java.util.Optional;
import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.InjectMocks;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;

/**
 * 수동 카드 그림의 명시 선택과 크레딧 (#407 Task S4).
 *
 * <p>앞쪽은 카드 추가(예약·건너뛰기), 뒤쪽은 커밋 뒤 그림 채우기(정산·반환)다. 그림은 부르지 않는다 — 목이다.
 */
@ExtendWith(MockitoExtension.class)
class RoutineStepImageCreditTest {

  private static final Caller GUARDIAN = Caller.guardian("member-1");
  private static final GeneratedImage IMAGE = new GeneratedImage(new byte[]{1}, "png");

  // --- 카드 추가(RoutineService) 쪽 ---
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

  // --- 그림 채우기(RoutineStepImageFiller) 쪽 — 실물을 목 의존으로 만든다 ---
  @Mock private CardImageGenerator cardImageGenerator;
  private RoutineStepImageFiller filler;

  @BeforeEach
  void setUp() {
    filler = new RoutineStepImageFiller(cardImageGenerator, routineImageStorage, routineStepRepository,
      aiDailyBudgetGuard, new RoutineStepImageThrottle(new InMemorySharedStateStore()), creditReservationService);
    lenient().when(routineStepRepository.existsById(anyString())).thenReturn(true);
    lenient().when(routineStepRepository.updateImagePath(anyString(), anyString())).thenReturn(1);
    lenient().when(routineImageStorage.save(anyString(), anyInt(), any())).thenReturn("images/step-1/1.png");
    lenient().when(cardImageGenerator.generate(any())).thenReturn(IMAGE);
  }

  @AfterEach
  void tearDown() {
    AiCallContext.clear();
  }

  // ── 카드 추가 ────────────────────────────────────────────────────

  @Test
  @DisplayName("generateImage 를 빼면 그림을 예약·생성하지 않는다 — 자동 그림은 없어졌다")
  void addStep_generateImageNull_noImageAtAll() {
    givenRoutine();

    RoutineResponse response = routineService.addStep(GUARDIAN, "routine-1",
      new RoutineStepCreateRequest("우산", "현관에서 우산을 챙겨요.", null));

    assertThat(response.imageSkippedReason()).isNull();
    verifyNoInteractions(routineStepImageFiller, creditReservationService);
  }

  @Test
  @DisplayName("generateImage=false 도 그림을 만들지 않는다")
  void addStep_generateImageFalse_noImage() {
    givenRoutine();

    routineService.addStep(GUARDIAN, "routine-1", new RoutineStepCreateRequest("우산", "현관에서 우산을 챙겨요.", false));

    verifyNoInteractions(routineStepImageFiller, creditReservationService);
  }

  @Test
  @DisplayName("generateImage=true 면 그림 1장을 초과 없이 예약하고, 작업 id 를 그림 채우기에 넘긴다")
  void addStep_generateImageTrue_reservesCardImageWithoutOverage() {
    givenRoutine();
    when(creditReservationService.reserve(eq("member-1"), eq(CreditJobKind.CARD_IMAGE), startsWith("card-image:"), eq(false)))
      .thenReturn(CreditReservation.reserved("job-7"));

    RoutineResponse response = routineService.addStep(GUARDIAN, "routine-1",
      new RoutineStepCreateRequest("우산", "현관에서 우산을 챙겨요.", true));

    assertThat(response.imageSkippedReason()).isNull();
    verify(routineStepImageFiller).scheduleAfterCommit(eq("member-1"), eq("routine-1"), any(),
      eq("현관에서 우산을 챙겨요."), any(), any(), eq("job-7"));
    // 카드를 지금 저장해 id 를 받는다 — 그래야 그림 채우기·정산이 카드를 찾는다
    verify(routineStepRepository).save(any(RoutineStep.class));
  }

  @Test
  @DisplayName("크레딧이 모자라면 카드는 저장하고 그림만 건너뛰며 까닭을 알린다")
  void addStep_insufficient_savesCardAndSkipsImage() {
    Routine routine = givenRoutine();
    when(creditReservationService.reserve(anyString(), eq(CreditJobKind.CARD_IMAGE), anyString(), eq(false)))
      .thenThrow(new CustomException(ErrorCode.AI_CREDIT_INSUFFICIENT));

    RoutineResponse response = routineService.addStep(GUARDIAN, "routine-1",
      new RoutineStepCreateRequest("우산", "현관에서 우산을 챙겨요.", true));

    assertThat(response.imageSkippedReason()).isEqualTo("AI_CREDIT_INSUFFICIENT");
    assertThat(routine.getSteps()).hasSize(2);
    assertThat(response.steps()).hasSize(2);
    verifyNoInteractions(routineStepImageFiller);
  }

  @Test
  @DisplayName("장부 오류면 카드 추가도 실패한다(fail-closed) — 트랜잭션이 이미 롤백 전용이다")
  void addStep_ledgerUnavailable_fails() {
    givenRoutine();
    when(creditReservationService.reserve(anyString(), any(), anyString(), eq(false)))
      .thenThrow(new CustomException(ErrorCode.AI_CREDIT_UNAVAILABLE));

    assertThatThrownBy(() -> routineService.addStep(GUARDIAN, "routine-1",
      new RoutineStepCreateRequest("우산", "현관에서 우산을 챙겨요.", true)))
      .hasFieldOrPropertyWithValue("errorCode", ErrorCode.AI_CREDIT_UNAVAILABLE);
    verifyNoInteractions(routineStepImageFiller);
  }

  @Test
  @DisplayName("크레딧이 꺼져 있으면 예전처럼 그림을 예약한다(작업 id 없음 — 비용 상한·횟수 제한만 본다)")
  void addStep_creditDisabled_schedulesWithoutJob() {
    givenRoutine();
    when(creditReservationService.reserve(anyString(), any(), anyString(), eq(false)))
      .thenReturn(CreditReservation.disabled());

    routineService.addStep(GUARDIAN, "routine-1", new RoutineStepCreateRequest("우산", "현관에서 우산을 챙겨요.", true));

    verify(routineStepImageFiller).scheduleAfterCommit(any(), any(), any(), any(), any(), any(), eq(null));
  }

  // ── 그림 채우기 ────────────────────────────────────────────────────

  private void fill(String jobId) {
    filler.fill("member-1", "routine-1", "step-1", "현관에서 우산을 챙겨요.", CharacterType.LULU, "seed", jobId);
  }

  @Test
  @DisplayName("그림이 카드에 붙으면 그림 1장으로 정산한다 — 반환하지 않는다")
  void fill_applied_settles() {
    fill("job-7");

    verify(creditReservationService).settle("job-7", 0, 1, "routine-1", "step-1");
    verify(creditReservationService, never()).release(anyString(), anyString());
  }

  @Test
  @DisplayName("그림 생성이 실패하면 반환한다")
  void fill_generationFails_releases() {
    when(cardImageGenerator.generate(any())).thenThrow(new IllegalStateException("provider down"));

    fill("job-7");

    verify(creditReservationService).release(eq("job-7"), anyString());
    verify(creditReservationService, never()).settle(anyString(), anyInt(), anyInt(), any(), any());
  }

  @Test
  @DisplayName("그림이 비어 돌아오면 반환한다")
  void fill_nullImage_releases() {
    when(cardImageGenerator.generate(any())).thenReturn(null);

    fill("job-7");

    verify(creditReservationService).release(eq("job-7"), anyString());
  }

  @Test
  @DisplayName("비용 상한에 걸려 건너뛰면 반환한다")
  void fill_budgetReached_releases() {
    when(aiDailyBudgetGuard.isReached()).thenReturn(true);

    fill("job-7");

    verify(creditReservationService).release(eq("job-7"), anyString());
    verifyNoInteractions(cardImageGenerator);
  }

  @Test
  @DisplayName("카드가 그사이 지워졌으면 반환한다 — 그림을 만든 뒤 지워진 경우도")
  void fill_cardDeleted_releases() {
    when(routineStepRepository.updateImagePath(anyString(), anyString())).thenReturn(0);

    fill("job-7");

    verify(creditReservationService).release(eq("job-7"), anyString());
    verify(creditReservationService, never()).settle(anyString(), anyInt(), anyInt(), any(), any());
  }

  @Test
  @DisplayName("정산이 실패해도 던지지 않고 반환한다 — 그림 1장이 무료가 될 뿐 빚을 남기지 않는다")
  void fill_settleFails_releases() {
    when(creditReservationService.settle(anyString(), anyInt(), anyInt(), any(), any()))
      .thenThrow(new CustomException(ErrorCode.AI_CREDIT_UNAVAILABLE));

    fill("job-7");

    verify(creditReservationService).release(eq("job-7"), anyString());
  }

  @Test
  @DisplayName("크레딧이 꺼져 작업이 없으면 정산·반환을 부르지 않는다")
  void fill_noJob_noCreditCalls() {
    fill(null);

    verify(routineStepRepository).updateImagePath("step-1", "images/step-1/1.png");
    verifyNoInteractions(creditReservationService);
  }

  @Test
  @DisplayName("그림 호출 맥락에 작업 id 를 싣는다 — 호출 기록이 작업에 이어진다")
  void fill_setsCreditJobIdOnContext() {
    java.util.concurrent.atomic.AtomicReference<String> seen = new java.util.concurrent.atomic.AtomicReference<>();
    when(cardImageGenerator.generate(any())).thenAnswer(i -> {
      seen.set(AiCallContext.currentCreditJobId());
      return IMAGE;
    });

    fill("job-7");

    assertThat(seen.get()).isEqualTo("job-7");
    assertThat(AiCallContext.currentCreditJobId()).isNull();
  }

  @Test
  @DisplayName("트랜잭션 밖에서 예약하면 그림을 걸 수 없어 반환한다")
  void schedule_outsideTransaction_releases() {
    filler.scheduleAfterCommit("member-1", "routine-1", "step-1", "설명", CharacterType.LULU, "seed", "job-7");

    verify(creditReservationService).release(eq("job-7"), anyString());
  }

  // ── 헬퍼 ────────────────────────────────────────────────────────

  private Routine givenRoutine() {
    Member member = new Member();
    member.setId("member-1");
    Profile profile = new Profile();
    profile.setId("profile-1");
    profile.setMember(member);
    Routine routine = new Routine();
    routine.setId("routine-1");
    routine.setTitle("학교 가기");
    routine.setProfile(profile);
    routine.setStatus(RoutineStatus.PENDING_REVIEW);
    routine.setCreatedBy("member-1");
    List<RoutineStep> steps = new ArrayList<>();
    RoutineStep step = new RoutineStep();
    step.setId("step-1");
    step.setStepOrder(1);
    step.setTitle("가방");
    step.setDescription("가방을 메요");
    step.setCompleted(false);
    steps.add(step);
    routine.setSteps(steps);
    when(routineRepository.findById("routine-1")).thenReturn(Optional.of(routine));
    return routine;
  }
}
