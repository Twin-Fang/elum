package com.chuseok22.elumserver.routine.application.service;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyBoolean;
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
import com.chuseok22.elumserver.routine.application.dto.request.RoutineStepImageRedrawRequest;
import com.chuseok22.elumserver.routine.application.dto.response.RoutineStepImageCandidateResponse;
import com.chuseok22.elumserver.routine.core.ImageRedrawHint;
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
import org.mockito.ArgumentCaptor;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.springframework.transaction.PlatformTransactionManager;

/**
 * 카드 그림 새로 그리기(후보): 권한·대상·크레딧 예약·정산·반환, 카드 그림은 그대로 (그림 생성·저장은 가짜, 실제 AI 호출 없음)
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
  @Mock private RoutineAiPicturePolicy routineAiPicturePolicy;

  private Routine routine;
  private RoutineStepImageRegenerateService service;

  @BeforeEach
  void setUp() {
    service = new RoutineStepImageRegenerateService(routineRepository, routineStepRepository, profileAccessGuard,
      cardImageGenerator, routineImageStorage, aiDailyBudgetGuard, routineStepImageThrottle, creditReservationService,
      routineAiPicturePolicy, mock(PlatformTransactionManager.class));
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
  @DisplayName("성공: IMAGE_REGENERATE 예약 > 그림 1장 정산 > 후보만 저장하고 카드 그림은 그대로 (이룸이는 아직 옛 그림)")
  void drawCandidate_aiPicture_reservesRegenerate_keepsImage() {
    RoutineStepImageCandidateResponse response = draw(null);

    assertThat(response.candidateImagePath()).isEqualTo(NEW_KEY);
    assertThat(response.isFirstPicture()).isFalse();
    assertThat(step().getImagePath()).isEqualTo(OLD_KEY);
    assertThat(step().getImageCandidatePath()).isEqualTo(NEW_KEY);
    verify(creditReservationService).reserve(eq("member-1"), eq(CreditJobKind.IMAGE_REGENERATE),
      startsWith(RoutineStepImageRegenerateService.REQUEST_KEY_PREFIX), eq(false));
    verify(creditReservationService).settle("job-1", 0, 1, "routine-1", "step-1");
    verify(creditReservationService, never()).release(anyString(), anyString());
    verify(routineImageStorage, never()).delete(anyString());
  }

  @Test
  @DisplayName("그림 없는 카드(픽토그램)는 처음 그리기 — 카드 그림 단가 CARD_IMAGE 로 예약 (무료 다시 그리기 한도 밖)")
  void drawCandidate_noPicture_reservesCardImage() {
    step().setImagePath(null);
    when(creditReservationService.reserve(eq("member-1"), eq(CreditJobKind.CARD_IMAGE), anyString(), eq(false)))
      .thenReturn(CreditReservation.reserved("job-2"));

    RoutineStepImageCandidateResponse response = draw(null);

    assertThat(response.isFirstPicture()).isTrue();
    assertThat(step().getImagePath()).isNull();
    verify(creditReservationService, never()).reserve(any(), eq(CreditJobKind.IMAGE_REGENERATE), any(), anyBoolean());
    verify(creditReservationService).settle("job-2", 0, 1, "routine-1", "step-1");
  }

  @Test
  @DisplayName("Free(AI 맞춤 그림 없음)는 예약·그림 전에 AI_IMAGE_NOT_ALLOWED — 원가가 나가지 않는다")
  void drawCandidate_free_rejectedBeforeReserve() {
    doThrow(new CustomException(ErrorCode.AI_IMAGE_NOT_ALLOWED)).when(routineAiPicturePolicy).requireAiPicture("member-1");

    assertErrorCode(() -> draw(null), ErrorCode.AI_IMAGE_NOT_ALLOWED);
    verifyNoInteractions(creditReservationService, cardImageGenerator);
  }

  @Test
  @DisplayName("보호자 요청(칩 + 글)이 그림 지시문의 guardianRequest 로 간다")
  void drawCandidate_passesGuardianRequest() {
    ArgumentCaptor<CardImageGenerator.CardImageRequest> captor = ArgumentCaptor.forClass(CardImageGenerator.CardImageRequest.class);

    draw(new RoutineStepImageRedrawRequest("우산을 파란색으로", List.of(ImageRedrawHint.SIMPLER)));

    verify(cardImageGenerator).generate(captor.capture());
    assertThat(captor.getValue().guardianRequest())
      .isEqualTo(ImageRedrawHint.SIMPLER.getInstruction() + " Guardian note: 우산을 파란색으로");
  }

  @Test
  @DisplayName("요청 글이 60자를 넘으면 예약 전에 INVALID_INPUT_VALUE")
  void drawCandidate_tooLongRequest_rejectedBeforeReserve() {
    assertErrorCode(() -> draw(new RoutineStepImageRedrawRequest("가".repeat(61), null)), ErrorCode.INVALID_INPUT_VALUE);
    verifyNoInteractions(creditReservationService, cardImageGenerator);
  }

  @Test
  @DisplayName("고르지 않은 옛 후보가 있으면 새 후보로 바꾸고 옛 후보 파일을 지운다")
  void drawCandidate_replacesPreviousCandidate() {
    step().setImageCandidatePath("step-1/ai-old-candidate.png");

    draw(null);

    assertThat(step().getImageCandidatePath()).isEqualTo(NEW_KEY);
    verify(routineImageStorage).delete("step-1/ai-old-candidate.png");
    verify(routineImageStorage, never()).delete(NEW_KEY);
  }

  @Test
  @DisplayName("그림 생성 실패: 예약을 돌려주고 카드 그림·후보 그대로, REGENERATE_FAILED (청구 없음)")
  void drawCandidate_generationFails_releases() {
    when(cardImageGenerator.generate(any())).thenThrow(new IllegalStateException("provider down"));

    assertErrorCode(() -> draw(null), ErrorCode.ROUTINE_STEP_IMAGE_REGENERATE_FAILED);

    verify(creditReservationService).release(eq("job-1"), anyString());
    verify(creditReservationService, never()).settle(anyString(), anyInt(), anyInt(), any(), any());
    assertThat(step().getImagePath()).isEqualTo(OLD_KEY);
    assertThat(step().getImageCandidatePath()).isNull();
  }

  @Test
  @DisplayName("그림이 비어 돌아오면 저장하지 않고 반환")
  void drawCandidate_emptyImage_releases() {
    when(cardImageGenerator.generate(any())).thenReturn(null);

    assertErrorCode(() -> draw(null), ErrorCode.ROUTINE_STEP_IMAGE_REGENERATE_FAILED);

    verify(routineImageStorage, never()).saveRegenerated(anyString(), any());
    verify(creditReservationService).release(eq("job-1"), anyString());
  }

  @Test
  @DisplayName("정산이 실패하면 새 그림을 지우고 반환")
  void drawCandidate_settleFails_deletesNewPictureAndReleases() {
    when(creditReservationService.settle("job-1", 0, 1, "routine-1", "step-1"))
      .thenThrow(new CustomException(ErrorCode.AI_CREDIT_UNAVAILABLE));

    assertErrorCode(() -> draw(null), ErrorCode.AI_CREDIT_UNAVAILABLE);

    verify(routineImageStorage).delete(NEW_KEY);
    verify(routineImageStorage, never()).delete(OLD_KEY);
    verify(creditReservationService).release(eq("job-1"), anyString());
  }

  @Test
  @DisplayName("그리는 사이 보호자가 사진으로 바꾸면 새 그림을 버리고 반환, NOT_REGENERATABLE")
  void drawCandidate_pictureChangedWhileDrawing_releases() {
    RoutineStep reloaded = new RoutineStep();
    reloaded.setId("step-1");
    reloaded.setImagePath("step-1/0f8fad5b-d9cb-469f-a165-70867728950e.jpg");
    when(routineStepRepository.findById("step-1")).thenReturn(Optional.of(reloaded));

    assertErrorCode(() -> draw(null), ErrorCode.ROUTINE_STEP_IMAGE_NOT_REGENERATABLE);

    assertThat(reloaded.getImageCandidatePath()).isNull();
    verify(routineImageStorage).delete(NEW_KEY);
    verify(creditReservationService).release(eq("job-1"), anyString());
  }

  @Test
  @DisplayName("그리는 사이 카드가 지워지면 새 그림을 버리고 반환, ROUTINE_STEP_NOT_FOUND")
  void drawCandidate_stepDeletedWhileDrawing() {
    when(routineStepRepository.findById("step-1")).thenReturn(Optional.empty());

    assertErrorCode(() -> draw(null), ErrorCode.ROUTINE_STEP_NOT_FOUND);

    verify(routineImageStorage).delete(NEW_KEY);
    verify(creditReservationService).release(eq("job-1"), anyString());
  }

  @Test
  @DisplayName("보호자 사진·가져온 그림 카드, 설명 없는 카드는 예약·생성 전에 NOT_REGENERATABLE (사진을 AI 그림으로 덮지 않게)")
  void drawCandidate_guardianPhoto_notRegeneratable() {
    for (String key : new String[]{"step-1/0f8fad5b-d9cb-469f-a165-70867728950e.jpg", "step-1/talk-abc.png"}) {
      step().setImagePath(key);
      assertErrorCode(() -> draw(null), ErrorCode.ROUTINE_STEP_IMAGE_NOT_REGENERATABLE);
    }
    step().setImagePath(null);
    step().setDescription(" ");
    assertErrorCode(() -> draw(null), ErrorCode.ROUTINE_STEP_IMAGE_NOT_REGENERATABLE);
    verifyNoInteractions(creditReservationService, cardImageGenerator);
  }

  @Test
  @DisplayName("직접 사진 방식 이룸이는 그림 없는 카드도 NOT_REGENERATABLE — AI 그림을 만들지 않는 방식")
  void drawCandidate_photoOnlyStyle_rejected() {
    routine.getProfile().setImageStyle(ImageStyle.PHOTO_ONLY);
    step().setImagePath(null);

    assertErrorCode(() -> draw(null), ErrorCode.ROUTINE_STEP_IMAGE_NOT_REGENERATABLE);
    verifyNoInteractions(creditReservationService, cardImageGenerator);
  }

  @Test
  @DisplayName("크레딧 부족이면 그 코드 그대로 — 그림을 부르지 않는다")
  void drawCandidate_insufficientCredit_propagates() {
    when(creditReservationService.reserve(eq("member-1"), eq(CreditJobKind.IMAGE_REGENERATE), anyString(), eq(false)))
      .thenThrow(new CustomException(ErrorCode.AI_CREDIT_INSUFFICIENT));

    assertErrorCode(() -> draw(null), ErrorCode.AI_CREDIT_INSUFFICIENT);
    verifyNoInteractions(cardImageGenerator);
  }

  @Test
  @DisplayName("하루 비용 상한이면 예약 전에 AI_DAILY_BUDGET_EXCEEDED")
  void drawCandidate_dailyBudget_rejectedBeforeReserve() {
    doThrow(new CustomException(ErrorCode.AI_DAILY_BUDGET_EXCEEDED)).when(aiDailyBudgetGuard).guard();

    assertErrorCode(() -> draw(null), ErrorCode.AI_DAILY_BUDGET_EXCEEDED);
    verifyNoInteractions(creditReservationService, cardImageGenerator);
  }

  @Test
  @DisplayName("그림 요청이 너무 잦으면 예약을 돌려주고 ROUTINE_REQUEST_TOO_FREQUENT")
  void drawCandidate_throttled_releases() {
    when(routineStepImageThrottle.tryAcquire("member-1")).thenReturn(false);

    assertErrorCode(() -> draw(null), ErrorCode.ROUTINE_REQUEST_TOO_FREQUENT);
    verify(creditReservationService).release(eq("job-1"), anyString());
    verifyNoInteractions(cardImageGenerator);
  }

  @Test
  @DisplayName("크레딧 정책이 꺼져 있으면 예약·정산 없이 후보만 만든다")
  void drawCandidate_creditDisabled_noSettlement() {
    when(creditReservationService.reserve(eq("member-1"), eq(CreditJobKind.IMAGE_REGENERATE), anyString(), eq(false)))
      .thenReturn(CreditReservation.disabled());

    RoutineStepImageCandidateResponse response = draw(null);

    assertThat(response.candidateImagePath()).isEqualTo(NEW_KEY);
    verify(creditReservationService, never()).settle(anyString(), anyInt(), anyInt(), any(), any());
    verify(creditReservationService, never()).release(anyString(), anyString());
  }

  private RoutineStepImageCandidateResponse draw(RoutineStepImageRedrawRequest request) {
    return service.drawCandidate(GUARDIAN, "routine-1", "step-1", request);
  }

  private RoutineStep step() {
    return routine.getSteps().get(0);
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
