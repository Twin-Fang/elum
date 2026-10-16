package com.chuseok22.elumserver.routine.application.service;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.ArgumentMatchers.startsWith;
import static org.mockito.Mockito.doAnswer;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

import com.chuseok22.elumserver.ai.core.AiCallContext;
import com.chuseok22.elumserver.common.locale.AppLocale;
import com.chuseok22.elumserver.credit.application.service.CreditReservation;
import com.chuseok22.elumserver.credit.application.service.CreditReservationService;
import com.chuseok22.elumserver.credit.core.CreditJobKind;
import com.chuseok22.elumserver.member.application.service.Caller;
import com.chuseok22.elumserver.member.application.service.ProfileAccessGuard;
import com.chuseok22.elumserver.member.infrastructure.entity.Profile;
import com.chuseok22.elumserver.member.infrastructure.repository.ProfileRepository;
import com.chuseok22.elumserver.routine.application.dto.request.RoutineStepCreateRequest;
import com.chuseok22.elumserver.routine.infrastructure.entity.Routine;
import com.chuseok22.elumserver.routine.infrastructure.entity.RoutineStatus;
import com.chuseok22.elumserver.routine.infrastructure.entity.RoutineStep;
import com.chuseok22.elumserver.routine.infrastructure.repository.RoutineRepository;
import com.chuseok22.elumserver.routine.infrastructure.repository.RoutineStepRepository;
import java.util.ArrayList;
import java.util.List;
import java.util.Optional;
import java.util.concurrent.atomic.AtomicReference;
import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.InjectMocks;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;

/** 카드 추가는 요청 헤더가 아니라 일과 언어로 AI 를 부르고, 끝나면 비운다. AI 는 부르지 않는다(피커·채우기는 목). */
@ExtendWith(MockitoExtension.class)
class RoutineServiceContentLocaleTest {

  private static final Caller GUARDIAN = Caller.guardian("member-1");

  @Mock private RoutineRepository routineRepository;
  @Mock private ProfileRepository profileRepository;
  @Mock private RoutineStepImageFiller routineStepImageFiller;
  @Mock private ProfileAccessGuard profileAccessGuard;
  @Mock private RoutineStepRepository routineStepRepository;
  @Mock private CreditReservationService creditReservationService;
  @Mock private PictogramPicker pictogramPicker;

  @InjectMocks private RoutineService routineService;

  @AfterEach
  void tearDown() {
    AiCallContext.clear();
  }

  @Test
  @DisplayName("카드 추가: 요청 헤더(ko)가 아니라 일과 언어(es)를 따른다 - 픽토그램 고르기와 그림 예약 모두")
  void addStep_followsTheRoutineLanguage_notTheRequest() {
    Routine routine = givenRoutine(AppLocale.ES);
    AtomicReference<AppLocale> seenByPicker = new AtomicReference<>();
    when(pictogramPicker.pick(any(), any(), any())).thenAnswer(invocation -> {
      seenByPicker.set(AiCallContext.currentContentLocale());
      return "brush_teeth";
    });
    when(creditReservationService.reserve(eq("member-1"), eq(CreditJobKind.CARD_IMAGE), startsWith("card-image:"), eq(false)))
      .thenReturn(CreditReservation.reserved("job-7"));
    AtomicReference<AppLocale> seenBySchedule = new AtomicReference<>();
    doAnswer(invocation -> {
      seenBySchedule.set(AiCallContext.currentContentLocale());
      return null;
    }).when(routineStepImageFiller).scheduleAfterCommit(any(), any(), any(), any(), any(), any(), any(), any());

    routineService.addStep(GUARDIAN, "routine-1", new RoutineStepCreateRequest("Paraguas", "Saca el paraguas.", true));

    assertThat(routine.getSteps()).hasSize(2);
    assertThat(seenByPicker.get()).isEqualTo(AppLocale.ES);
    assertThat(seenBySchedule.get()).isEqualTo(AppLocale.ES);
    // 풀의 요청 스레드가 다음 요청에 es 를 새지 않게 비운다
    assertThat(AiCallContext.currentContentLocale()).isEqualTo(AppLocale.KO);
  }

  @Test
  @DisplayName("카드 추가: 보호자가 카드에 적은 이름도 es 일과에서는 자리표시(Elumi)로 바뀌어 AI 로 나간다")
  void addStep_masksNicknameWithTheRoutineLanguage() {
    givenRoutine(AppLocale.ES);
    when(pictogramPicker.pick(any(), any(), any())).thenReturn("brush_teeth");

    routineService.addStep(GUARDIAN, "routine-1", new RoutineStepCreateRequest("Paraguas de Haneul", "Haneul saca el paraguas", false));

    verify(pictogramPicker).pick("member-1", "Paraguas de Elumi", "Elumi saca el paraguas");
  }

  @Test
  @DisplayName("카드 추가: 픽토그램 고르기가 던져도 일과 언어는 비워진다")
  void addStep_clearsLocaleWhenPickerThrows() {
    givenRoutine(AppLocale.ES);
    when(pictogramPicker.pick(any(), any(), any())).thenThrow(new IllegalStateException("picker down"));

    try {
      routineService.addStep(GUARDIAN, "routine-1", new RoutineStepCreateRequest("Paraguas", "", false));
    } catch (IllegalStateException expected) {
      // 비우는 것만 확인한다
    }

    assertThat(AiCallContext.currentContentLocale()).isEqualTo(AppLocale.KO);
  }

  private Routine givenRoutine(AppLocale language) {
    Profile profile = new Profile();
    profile.setId("profile-1");
    profile.setNickname("Haneul");
    Routine routine = new Routine();
    routine.setId("routine-1");
    routine.setTitle("Ir al colegio");
    routine.setProfile(profile);
    routine.setStatus(RoutineStatus.PENDING_REVIEW);
    routine.setCreatedBy("member-1");
    routine.setLanguage(language);
    List<RoutineStep> steps = new ArrayList<>();
    RoutineStep step = new RoutineStep();
    step.setId("step-1");
    step.setStepOrder(1);
    step.setTitle("Mochila");
    step.setDescription("Lleva la mochila");
    step.setCompleted(false);
    steps.add(step);
    routine.setSteps(steps);
    when(routineRepository.findById("routine-1")).thenReturn(Optional.of(routine));
    return routine;
  }
}
