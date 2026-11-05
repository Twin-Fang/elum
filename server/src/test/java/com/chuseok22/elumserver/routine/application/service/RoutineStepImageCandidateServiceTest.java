package com.chuseok22.elumserver.routine.application.service;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.ArgumentMatchers.anyString;
import static org.mockito.Mockito.lenient;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

import com.chuseok22.elumserver.common.infrastructure.exception.ErrorCode;
import com.chuseok22.elumserver.member.application.service.Caller;
import com.chuseok22.elumserver.member.application.service.ProfileAccessGuard;
import com.chuseok22.elumserver.member.infrastructure.entity.Profile;
import com.chuseok22.elumserver.routine.application.dto.response.RoutineStepResponse;
import com.chuseok22.elumserver.routine.infrastructure.entity.Routine;
import com.chuseok22.elumserver.routine.infrastructure.entity.RoutineStatus;
import com.chuseok22.elumserver.routine.infrastructure.entity.RoutineStep;
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
 * 새 그림 후보 고르기: 깨지면 보호자가 고르지 않은 그림이 이룸이에게 가거나, 고른 그림이 반영되지 않는다
 */
@ExtendWith(MockitoExtension.class)
class RoutineStepImageCandidateServiceTest {

  private static final Caller GUARDIAN = Caller.guardian("member-1");
  private static final String OLD_KEY = "batch-1/1.png";
  private static final String CANDIDATE_KEY = "step-1/ai-new.png";

  @Mock private RoutineRepository routineRepository;
  @Mock private RoutineStepRepository routineStepRepository;
  @Mock private ProfileAccessGuard profileAccessGuard;
  @Mock private RoutineImageStorage routineImageStorage;

  private Routine routine;
  private RoutineStepImageCandidateService service;

  @BeforeEach
  void setUp() {
    service = new RoutineStepImageCandidateService(routineRepository, routineStepRepository, profileAccessGuard,
      routineImageStorage, mock(PlatformTransactionManager.class));
    routine = routine();
    lenient().when(routineRepository.findById("routine-1")).thenReturn(Optional.of(routine));
  }

  @Test
  @DisplayName("고르면 후보가 카드 그림이 되고 후보는 비며, 옛 AI 그림 파일을 지운다")
  void apply_swapsAndDeletesOld() {
    step().setImageCandidatePath(CANDIDATE_KEY);

    RoutineStepResponse response = service.applyCandidate(GUARDIAN, "routine-1", "step-1", CANDIDATE_KEY);

    assertThat(response.imagePath()).isEqualTo(CANDIDATE_KEY);
    assertThat(response.aiPicture()).isTrue();
    assertThat(step().getImagePath()).isEqualTo(CANDIDATE_KEY);
    assertThat(step().getImageCandidatePath()).isNull();
    verify(routineImageStorage).delete(OLD_KEY);
  }

  @Test
  @DisplayName("그림 없던 카드(픽토그램)에서 고르면 지울 옛 그림이 없다")
  void apply_firstPicture_nothingToDelete() {
    step().setImagePath(null);
    step().setImageCandidatePath(CANDIDATE_KEY);

    service.applyCandidate(GUARDIAN, "routine-1", "step-1", CANDIDATE_KEY);

    assertThat(step().getImagePath()).isEqualTo(CANDIDATE_KEY);
    verify(routineImageStorage, never()).delete(anyString());
  }

  @Test
  @DisplayName("지금 후보와 다른 열쇠(다시 그려 바뀜·이미 고름)는 404, 카드 그림 그대로")
  void apply_staleCandidate_rejected() {
    step().setImageCandidatePath("step-1/ai-newer.png");

    assertThatThrownBy(() -> service.applyCandidate(GUARDIAN, "routine-1", "step-1", CANDIDATE_KEY))
      .hasFieldOrPropertyWithValue("errorCode", ErrorCode.ROUTINE_STEP_IMAGE_CANDIDATE_NOT_FOUND);
    step().setImageCandidatePath(null);
    assertThatThrownBy(() -> service.applyCandidate(GUARDIAN, "routine-1", "step-1", CANDIDATE_KEY))
      .hasFieldOrPropertyWithValue("errorCode", ErrorCode.ROUTINE_STEP_IMAGE_CANDIDATE_NOT_FOUND);

    assertThat(step().getImagePath()).isEqualTo(OLD_KEY);
    verify(routineImageStorage, never()).delete(anyString());
  }

  @Test
  @DisplayName("원래 그림 그대로: 후보를 비우고 파일을 지운다. 후보가 없어도 성공")
  void discard_clearsAndDeletes() {
    step().setImageCandidatePath(CANDIDATE_KEY);

    service.discardCandidate(GUARDIAN, "routine-1", "step-1");
    service.discardCandidate(GUARDIAN, "routine-1", "step-1");

    assertThat(step().getImageCandidatePath()).isNull();
    assertThat(step().getImagePath()).isEqualTo(OLD_KEY);
    verify(routineImageStorage).delete(CANDIDATE_KEY);
  }

  @Test
  @DisplayName("후보가 없으면 받기는 404 ROUTINE_STEP_IMAGE_CANDIDATE_NOT_FOUND, 있으면 그 열쇠를 읽는다")
  void read_noCandidate_notFound() {
    assertThatThrownBy(() -> service.readCandidate(GUARDIAN, "routine-1", "step-1"))
      .hasFieldOrPropertyWithValue("errorCode", ErrorCode.ROUTINE_STEP_IMAGE_CANDIDATE_NOT_FOUND);

    step().setImageCandidatePath(CANDIDATE_KEY);
    RoutineImageStorage.ImageContent content = new RoutineImageStorage.ImageContent(new byte[]{1}, "image/png");
    when(routineImageStorage.read(CANDIDATE_KEY)).thenReturn(content);
    assertThat(service.readCandidate(GUARDIAN, "routine-1", "step-1")).isSameAs(content);
  }

  private RoutineStep step() {
    return routine.getSteps().get(0);
  }

  private static Routine routine() {
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
    step.setDescription("옷을 입어요");
    step.setImagePath(OLD_KEY);
    List<RoutineStep> steps = new ArrayList<>();
    steps.add(step);
    routine.setSteps(steps);
    return routine;
  }
}
