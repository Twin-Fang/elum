package com.chuseok22.elumserver.routine.application.service;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.Mockito.when;

import com.chuseok22.elumserver.common.infrastructure.exception.CustomException;
import com.chuseok22.elumserver.common.infrastructure.exception.ErrorCode;
import com.chuseok22.elumserver.common.locale.AppLocale;
import com.chuseok22.elumserver.credit.application.service.CreditReservationService;
import com.chuseok22.elumserver.member.application.service.Caller;
import com.chuseok22.elumserver.member.application.service.ProfileAccessGuard;
import com.chuseok22.elumserver.member.infrastructure.entity.Profile;
import com.chuseok22.elumserver.member.infrastructure.repository.ProfileRepository;
import com.chuseok22.elumserver.routine.application.dto.RoutineShareSnapshot;
import com.chuseok22.elumserver.routine.application.dto.request.RoutineStepUpdateRequest;
import com.chuseok22.elumserver.routine.application.dto.response.RoutineResponse;
import com.chuseok22.elumserver.routine.infrastructure.entity.Routine;
import com.chuseok22.elumserver.routine.infrastructure.entity.RoutineStatus;
import com.chuseok22.elumserver.routine.infrastructure.entity.RoutineStep;
import com.chuseok22.elumserver.routine.infrastructure.repository.RoutineGroupRepository;
import com.chuseok22.elumserver.routine.infrastructure.repository.RoutineRepository;
import com.chuseok22.elumserver.routine.infrastructure.repository.RoutineStepRepository;
import com.chuseok22.elumserver.routine.infrastructure.storage.RoutineImageStorage;
import java.util.ArrayList;
import java.util.Optional;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.InjectMocks;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.springframework.context.ApplicationEventPublisher;

/// 예시 일과 고치기 > 이야기 올리기 (#983). 깨지면 고친 예시를 영영 못 올리거나, 손대지 않은 예시가 이야기에 올라감
@ExtendWith(MockitoExtension.class)
class RoutineExampleEditShareTest {

  private static final Caller GUARDIAN = Caller.guardian("member-1");
  private static final String EXAMPLE_ROUTINE_ID = "example-1";

  // 세 서비스가 같은 일과 저장소를 본다 (고친 결과가 공유 판정에 그대로 이어짐)
  @Mock private RoutineRepository routineRepository;
  @Mock private ProfileAccessGuard profileAccessGuard;
  @Mock private RoutineStepSpeechQueue routineStepSpeechQueue;
  @Mock private RoutineGroupMembership routineGroupMembership;
  @Mock private ApplicationEventPublisher eventPublisher;
  @Mock private ProfileRepository profileRepository;
  @Mock private RoutineStepImageFiller routineStepImageFiller;
  @Mock private RoutineStepRepository routineStepRepository;
  @Mock private CreditReservationService creditReservationService;
  @Mock private PictogramPicker pictogramPicker;
  @Mock private RoutineImageStorage routineImageStorage;
  @Mock private RoutineGroupRepository routineGroupRepository;
  @Mock private RoutineLibraryOrderService routineLibraryOrderService;

  @InjectMocks private RoutineService routineService;
  @InjectMocks private RoutineStepEditService routineStepEditService;
  @InjectMocks private RoutineShareService routineShareService;

  private Routine example;

  @BeforeEach
  void setUp() {
    example = exampleRoutine();
    when(routineRepository.findById(EXAMPLE_ROUTINE_ID)).thenReturn(Optional.of(example));
  }

  @Test
  @DisplayName("예시 일과 제목을 고치면 예시 표시가 지워지고 이야기에 올릴 수 있다")
  void renamedExample_becomesShareable() {
    RoutineResponse renamed = routineService.rename(GUARDIAN, EXAMPLE_ROUTINE_ID, "하늘이 아침 준비");

    assertThat(renamed.isExample()).isFalse();
    RoutineShareSnapshot snapshot = routineShareService.snapshotForShare(GUARDIAN, EXAMPLE_ROUTINE_ID);
    assertThat(snapshot.originalRoutineId()).isEqualTo(EXAMPLE_ROUTINE_ID);
    assertThat(snapshot.title()).isEqualTo("하늘이 아침 준비");
  }

  @Test
  @DisplayName("같은 제목 저장 · 카드 순서만 바꾸기는 고침이 아니다 — 예시 표시가 남아 올릴 수 없다")
  void unchangedTextEdits_keepExampleBlocked() {
    routineService.rename(GUARDIAN, EXAMPLE_ROUTINE_ID, "  아침 준비  ");
    routineStepEditService.updateStep(
      GUARDIAN, EXAMPLE_ROUTINE_ID, "step-2", new RoutineStepUpdateRequest(null, null, 1));

    assertThat(example.getIsExample()).isTrue();
    assertThatThrownBy(() -> routineShareService.snapshotForShare(GUARDIAN, EXAMPLE_ROUTINE_ID))
      .isInstanceOfSatisfying(CustomException.class,
        e -> assertThat(e.getErrorCode()).isEqualTo(ErrorCode.TALK_ROUTINE_NOT_SHAREABLE));
  }

  private static Routine exampleRoutine() {
    Profile profile = new Profile();
    profile.setId("profile-1");
    profile.setNickname("하늘이");
    Routine routine = new Routine();
    routine.setId(EXAMPLE_ROUTINE_ID);
    routine.setProfile(profile);
    routine.setCreatedBy("member-1");
    routine.setTitle("아침 준비");
    routine.setStatus(RoutineStatus.CONFIRMED);
    routine.setLanguage(AppLocale.KO);
    routine.setIsExample(true);
    routine.setSteps(new ArrayList<>());
    routine.getSteps().add(step(routine, "step-1", 1, "세수해요"));
    routine.getSteps().add(step(routine, "step-2", 2, "옷을 입어요"));
    return routine;
  }

  private static RoutineStep step(Routine routine, String id, int order, String text) {
    RoutineStep step = new RoutineStep();
    step.setId(id);
    step.setRoutine(routine);
    step.setStepOrder(order);
    step.setTitle(text);
    step.setDescription(text);
    step.setCompleted(false);
    return step;
  }
}
