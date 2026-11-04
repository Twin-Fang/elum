package com.chuseok22.elumserver.routine.application.service;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyInt;
import static org.mockito.ArgumentMatchers.anyString;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.ArgumentMatchers.startsWith;
import static org.mockito.Mockito.doThrow;
import static org.mockito.Mockito.lenient;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.verifyNoInteractions;
import static org.mockito.Mockito.when;

import com.chuseok22.elumserver.ai.application.service.CardImageGenerator;
import com.chuseok22.elumserver.ai.core.GeneratedImage;
import com.chuseok22.elumserver.common.infrastructure.exception.CustomException;
import com.chuseok22.elumserver.common.infrastructure.exception.ErrorCode;
import com.chuseok22.elumserver.credit.application.service.CreditReservation;
import com.chuseok22.elumserver.credit.application.service.CreditReservationService;
import com.chuseok22.elumserver.credit.core.CreditJobKind;
import com.chuseok22.elumserver.member.application.service.Caller;
import com.chuseok22.elumserver.member.application.service.ProfileAccessGuard;
import com.chuseok22.elumserver.member.infrastructure.entity.ImageStyle;
import com.chuseok22.elumserver.member.infrastructure.entity.Profile;
import com.chuseok22.elumserver.routine.application.dto.response.RoutineStepResponse;
import com.chuseok22.elumserver.routine.infrastructure.entity.Routine;
import com.chuseok22.elumserver.routine.infrastructure.entity.RoutineStatus;
import com.chuseok22.elumserver.routine.infrastructure.entity.RoutineStep;
import com.chuseok22.elumserver.routine.infrastructure.guard.RoutineStepImageThrottle;
import com.chuseok22.elumserver.routine.infrastructure.repository.RoutineRepository;
import com.chuseok22.elumserver.routine.infrastructure.repository.RoutineStepRepository;
import com.chuseok22.elumserver.routine.infrastructure.storage.RoutineImageStorage;
import java.util.ArrayList;
import java.util.List;
import java.util.Optional;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.springframework.transaction.PlatformTransactionManager;

/**
 * 카드 그림 다시 그리기: 크레딧 예약·정산·반환과 카드 그림 교체 (그림 생성·저장은 가짜, 실제 AI 호출 없음)
 * 무료/유료 단가 판정(Pro 하루 한도 안 0 · Free 정책 단가)은 CreditReservationServiceTest 의 regenerate_* 가 맡는다
 */
@ExtendWith(MockitoExtension.class)
class RoutineStepImageRegenerateServiceTest {

  private static final Caller GUARDIAN = Caller.guardian("member-1");
  private static final String OLD_KEY = "batch-1/1.png";
  private static final String NEW_KEY = "step-1/ai-new.png";
  private static final GeneratedImage IMAGE = new GeneratedImage(new byte[]{1, 2}, "png");

  @Mock private RoutineRepository routineRepository;
  @Mock private RoutineStepRepository routineStepRepository;
  @Mock private ProfileAccessGuard profileAccessGuard;
  @Mock private CardImageGenerator cardImageGenerator;
  @Mock private RoutineImageStorage routineImageStorage;
  @Mock private AiDailyBudgetGuard aiDailyBudgetGuard;
  @Mock private RoutineStepImageThrottle routineStepImageThrottle;
  @Mock private CreditReservationService creditReservationService;

  private Routine routine;
  private RoutineStepImageRegenerateService service;

  @BeforeEach
  void setUp() {
    service = new RoutineStepImageRegenerateService(routineRepository, routineStepRepository, profileAccessGuard,
      cardImageGenerator, routineImageStorage, aiDailyBudgetGuard, routineStepImageThrottle, creditReservationService,
      mock(PlatformTransactionManager.class));
    routine = routine(OLD_KEY);
    lenient().when(routineRepository.findById("routine-1")).thenReturn(Optional.of(routine));
    lenient().when(routineStepRepository.findById("step-1")).thenReturn(Optional.of(routine.getSteps().get(0)));
    lenient().when(creditReservationService.reserve(eq("member-1"), eq(CreditJobKind.IMAGE_REGENERATE), anyString(), eq(false)))
      .thenReturn(CreditReservation.reserved("job-1"));
    lenient().when(routineStepImageThrottle.tryAcquire("member-1")).thenReturn(true);
    lenient().when(cardImageGenerator.generate(any())).thenReturn(IMAGE);
    lenient().when(routineImageStorage.saveRegenerated("step-1", IMAGE)).thenReturn(NEW_KEY);
  }

  @Test
  @DisplayName("성공: IMAGE_REGENERATE 예약 > 그림 1장 정산 > 카드 그림이 새 열쇠로 바뀌고 옛 그림을 지운다 (반환 없음)")
  void regenerate_replacesPictureAndSettles() {
    RoutineStepResponse response = service.regenerate(GUARDIAN, "routine-1", "step-1");

    assertThat(response.imagePath()).isEqualTo(NEW_KEY);
    assertThat(response.aiPicture()).isTrue();
    assertThat(routine.getSteps().get(0).getImagePath()).isEqualTo(NEW_KEY);
    verify(creditReservationService).reserve(eq("member-1"), eq(CreditJobKind.IMAGE_REGENERATE),
      startsWith(RoutineStepImageRegenerateService.REQUEST_KEY_PREFIX), eq(false));
    verify(creditReservationService).settle("job-1", 0, 1, "routine-1", "step-1");
    verify(creditReservationService, never()).release(anyString(), anyString());
    verify(routineImageStorage).delete(OLD_KEY);
  }

  @Test
  @DisplayName("성공: 복제 일과가 옛 그림을 같이 쓰면 옛 그림을 지우지 않는다 (복제본 그림이 깨지지 않게)")
  void regenerate_keepsSharedOldPicture() {
    when(routineStepRepository.existsByImagePathAndIdNot(OLD_KEY, "step-1")).thenReturn(true);

    service.regenerate(GUARDIAN, "routine-1", "step-1");

    verify(routineImageStorage, never()).delete(OLD_KEY);
  }

  @Test
  @DisplayName("그림 생성 실패: 예약을 돌려주고 카드 그림은 그대로, REGENERATE_FAILED (청구 없음)")
  void regenerate_generationFails_refundsAndKeepsPicture() {
    when(cardImageGenerator.generate(any())).thenThrow(new IllegalStateException("provider down"));

    assertErrorCode(() -> service.regenerate(GUARDIAN, "routine-1", "step-1"),
      ErrorCode.ROUTINE_STEP_IMAGE_REGENERATE_FAILED);

    verify(creditReservationService).release(eq("job-1"), anyString());
    verify(creditReservationService, never()).settle(anyString(), anyInt(), anyInt(), any(), any());
    assertThat(routine.getSteps().get(0).getImagePath()).isEqualTo(OLD_KEY);
  }

  @Test
  @DisplayName("그림이 비어 돌아오면 저장하지 않고 반환")
  void regenerate_emptyImage_refunds() {
    when(cardImageGenerator.generate(any())).thenReturn(null);

    assertErrorCode(() -> service.regenerate(GUARDIAN, "routine-1", "step-1"),
      ErrorCode.ROUTINE_STEP_IMAGE_REGENERATE_FAILED);

    verify(routineImageStorage, never()).saveRegenerated(anyString(), any());
    verify(creditReservationService).release(eq("job-1"), anyString());
  }

  @Test
  @DisplayName("정산이 실패하면 새 그림을 지우고 반환 — 카드는 옛 그림을 가리킨 채 청구도 없다")
  void regenerate_settleFails_deletesNewPictureAndRefunds() {
    when(creditReservationService.settle("job-1", 0, 1, "routine-1", "step-1"))
      .thenThrow(new CustomException(ErrorCode.AI_CREDIT_UNAVAILABLE));

    assertErrorCode(() -> service.regenerate(GUARDIAN, "routine-1", "step-1"), ErrorCode.AI_CREDIT_UNAVAILABLE);

    verify(routineImageStorage).delete(NEW_KEY);
    verify(routineImageStorage, never()).delete(OLD_KEY);
    verify(creditReservationService).release(eq("job-1"), anyString());
  }

  @Test
  @DisplayName("그리는 사이 카드가 지워지면 새 그림을 버리고 반환, ROUTINE_STEP_NOT_FOUND")
  void regenerate_stepDeletedWhileDrawing() {
    when(routineStepRepository.findById("step-1")).thenReturn(Optional.empty());

    assertErrorCode(() -> service.regenerate(GUARDIAN, "routine-1", "step-1"), ErrorCode.ROUTINE_STEP_NOT_FOUND);

    verify(routineImageStorage).delete(NEW_KEY);
    verify(creditReservationService).release(eq("job-1"), anyString());
  }

  @Test
  @DisplayName("보호자 사진·가져온 그림·그림 없는 카드는 예약·생성 전에 NOT_REGENERATABLE (사진을 AI 그림으로 덮지 않게)")
  void regenerate_notAiPicture_rejectedBeforeSpending() {
    for (String key : new String[]{"step-1/0f8fad5b-d9cb-469f-a165-70867728950e.jpg", "step-1/talk-abc.png", null}) {
      routine.getSteps().get(0).setImagePath(key);

      assertErrorCode(() -> service.regenerate(GUARDIAN, "routine-1", "step-1"),
        ErrorCode.ROUTINE_STEP_IMAGE_NOT_REGENERATABLE);
    }
    verifyNoInteractions(creditReservationService, cardImageGenerator);
  }

  @Test
  @DisplayName("직접 사진 방식 이룸이는 NOT_REGENERATABLE — AI 그림을 만들지 않는 방식")
  void regenerate_photoOnlyStyle_rejected() {
    routine.getProfile().setImageStyle(ImageStyle.PHOTO_ONLY);

    assertErrorCode(() -> service.regenerate(GUARDIAN, "routine-1", "step-1"),
      ErrorCode.ROUTINE_STEP_IMAGE_NOT_REGENERATABLE);
    verifyNoInteractions(creditReservationService, cardImageGenerator);
  }

  @Test
  @DisplayName("크레딧 부족이면 그 코드 그대로 — 그림을 부르지 않는다")
  void regenerate_insufficientCredit_propagates() {
    when(creditReservationService.reserve(eq("member-1"), eq(CreditJobKind.IMAGE_REGENERATE), anyString(), eq(false)))
      .thenThrow(new CustomException(ErrorCode.AI_CREDIT_INSUFFICIENT));

    assertErrorCode(() -> service.regenerate(GUARDIAN, "routine-1", "step-1"), ErrorCode.AI_CREDIT_INSUFFICIENT);
    verifyNoInteractions(cardImageGenerator);
  }

  @Test
  @DisplayName("하루 비용 상한이면 예약 전에 AI_DAILY_BUDGET_EXCEEDED")
  void regenerate_dailyBudget_rejectedBeforeReserve() {
    doThrow(new CustomException(ErrorCode.AI_DAILY_BUDGET_EXCEEDED)).when(aiDailyBudgetGuard).guard();

    assertErrorCode(() -> service.regenerate(GUARDIAN, "routine-1", "step-1"), ErrorCode.AI_DAILY_BUDGET_EXCEEDED);
    verifyNoInteractions(creditReservationService, cardImageGenerator);
  }

  @Test
  @DisplayName("그림 요청이 너무 잦으면 예약을 돌려주고 ROUTINE_REQUEST_TOO_FREQUENT")
  void regenerate_throttled_refunds() {
    when(routineStepImageThrottle.tryAcquire("member-1")).thenReturn(false);

    assertErrorCode(() -> service.regenerate(GUARDIAN, "routine-1", "step-1"), ErrorCode.ROUTINE_REQUEST_TOO_FREQUENT);
    verify(creditReservationService).release(eq("job-1"), anyString());
    verifyNoInteractions(cardImageGenerator);
  }

  @Test
  @DisplayName("크레딧 정책이 꺼져 있으면 예약·정산 없이 그림만 바꾼다")
  void regenerate_creditDisabled_noSettlement() {
    when(creditReservationService.reserve(eq("member-1"), eq(CreditJobKind.IMAGE_REGENERATE), anyString(), eq(false)))
      .thenReturn(CreditReservation.disabled());

    RoutineStepResponse response = service.regenerate(GUARDIAN, "routine-1", "step-1");

    assertThat(response.imagePath()).isEqualTo(NEW_KEY);
    verify(creditReservationService, never()).settle(anyString(), anyInt(), anyInt(), any(), any());
    verify(creditReservationService, never()).release(anyString(), anyString());
  }

  private static void assertErrorCode(org.assertj.core.api.ThrowableAssert.ThrowingCallable call, ErrorCode code) {
    assertThatThrownBy(call)
      .isInstanceOf(CustomException.class)
      .satisfies(e -> assertThat(((CustomException) e).getErrorCode()).isEqualTo(code));
  }

  private static Routine routine(String imagePath) {
    Profile profile = new Profile();
    profile.setId("profile-1");

    Routine routine = new Routine();
    routine.setId("routine-1");
    routine.setTitle("아침 준비");
    routine.setProfile(profile);
    routine.setStatus(RoutineStatus.CONFIRMED);
    routine.setCreatedBy("member-1");

    RoutineStep step = new RoutineStep();
    step.setId("step-1");
    step.setRoutine(routine);
    step.setStepOrder(1);
    step.setTitle("옷 입기");
    step.setDescription("옷을 입어요");
    step.setImagePath(imagePath);
    List<RoutineStep> steps = new ArrayList<>();
    steps.add(step);
    routine.setSteps(steps);
    return routine;
  }
}
