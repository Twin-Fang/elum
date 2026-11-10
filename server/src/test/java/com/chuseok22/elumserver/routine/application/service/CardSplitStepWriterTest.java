package com.chuseok22.elumserver.routine.application.service;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

import com.chuseok22.elumserver.common.infrastructure.exception.ErrorCode;
import com.chuseok22.elumserver.member.application.service.Caller;
import com.chuseok22.elumserver.member.application.service.ProfileAccessGuard;
import com.chuseok22.elumserver.member.infrastructure.entity.Profile;
import com.chuseok22.elumserver.routine.application.dto.request.CardSplitRequest;
import com.chuseok22.elumserver.routine.application.dto.response.RoutineResponse;
import com.chuseok22.elumserver.routine.infrastructure.entity.Routine;
import com.chuseok22.elumserver.routine.infrastructure.entity.RoutineStatus;
import com.chuseok22.elumserver.routine.infrastructure.entity.RoutineStep;
import com.chuseok22.elumserver.routine.infrastructure.repository.RoutineRepository;
import com.chuseok22.elumserver.routine.infrastructure.repository.RoutineStepRepository;
import java.util.ArrayList;
import java.util.List;
import java.util.Optional;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.InjectMocks;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;

/// 카드 교체: 그 자리에 순서대로, 뒤 카드는 밀리고, 원래 카드는 없어지며, 한도·완료 카드는 막는가
@ExtendWith(MockitoExtension.class)
class CardSplitStepWriterTest {

  private static final Caller GUARDIAN = Caller.guardian("member-1");

  @Mock private RoutineRepository routineRepository;
  @Mock private ProfileAccessGuard profileAccessGuard;
  @Mock private RoutineStepRepository routineStepRepository;
  @Mock private RoutineStepSpeechQueue routineStepSpeechQueue;
  @Mock private GuardianVoiceFiles guardianVoiceFiles;
  @InjectMocks private CardSplitStepWriter cardSplitStepWriter;

  private static final List<CardSplitRequest.Card> TWO_CARDS = List.of(
    new CardSplitRequest.Card(" 양치해요 ", "이를 닦아요."), new CardSplitRequest.Card("세수해요", null));

  @Test
  @DisplayName("가운데 카드를 나누면 새 카드가 그 자리에 순서대로 들어가고 뒤 카드가 밀린다 — 순서는 1..N 으로 이어진다")
  void replaceStep_insertsInPlaceAndShiftsFollowing() {
    Routine routine = routine(4);
    when(routineRepository.findById("routine-1")).thenReturn(Optional.of(routine));

    RoutineResponse response = cardSplitStepWriter.replaceStep(
      GUARDIAN, "routine-1", "step-2", TWO_CARDS, List.of("brush", "wash"));

    assertThat(routine.getSteps()).extracting(RoutineStep::getStepOrder).containsExactlyInAnyOrder(1, 2, 3, 4, 5);
    List<String> titlesInOrder = routine.getSteps().stream()
      .sorted(java.util.Comparator.comparingInt(RoutineStep::getStepOrder)).map(RoutineStep::getTitle).toList();
    assertThat(titlesInOrder).containsExactly("제목 1", "양치해요", "세수해요", "제목 3", "제목 4");
    assertThat(routine.getSteps()).noneMatch(step -> "step-2".equals(step.getId()));
    assertThat(response.steps()).hasSize(5);
  }

  @Test
  @DisplayName("새 카드는 미완료·무료 픽토그램만 갖고 소리를 예약하며, 원래 카드의 소리·녹음은 정리를 예약한다")
  void replaceStep_newCardsGetPictogramAndSpeech() {
    Routine routine = routine(2);
    when(routineRepository.findById("routine-1")).thenReturn(Optional.of(routine));

    cardSplitStepWriter.replaceStep(GUARDIAN, "routine-1", "step-1", TWO_CARDS, List.of("brush", "wash"));

    RoutineStep first = routine.getSteps().stream().filter(step -> "양치해요".equals(step.getTitle())).findFirst().orElseThrow();
    assertThat(first.getPictogramId()).isEqualTo("brush");
    assertThat(first.getCompleted()).isFalse();
    assertThat(first.getImagePath()).isNull();
    assertThat(routine.getSteps().stream().filter(step -> "세수해요".equals(step.getTitle())).findFirst().orElseThrow()
      .getDescription()).isEmpty();
    verify(routineStepSpeechQueue).deleteStepsAfterCommit(List.of("step-1"));
    verify(routineStepRepository, org.mockito.Mockito.times(2)).save(any(RoutineStep.class));
  }

  @Test
  @DisplayName("나누면 10장을 넘게 될 때 409 ROUTINE_STEP_MAX_COUNT 이고 카드를 바꾸지 않는다")
  void replaceStep_rejectsOverMaxCount() {
    Routine routine = routine(10);
    when(routineRepository.findById("routine-1")).thenReturn(Optional.of(routine));

    assertThatThrownBy(() -> cardSplitStepWriter.replaceStep(
      GUARDIAN, "routine-1", "step-1", TWO_CARDS, List.of("a", "b")))
      .extracting("errorCode").isEqualTo(ErrorCode.ROUTINE_STEP_MAX_COUNT);
    assertThat(routine.getSteps()).hasSize(10);
    verify(routineStepRepository, never()).save(any());
  }

  @Test
  @DisplayName("이미 완료한 카드는 나눌 수 없다 — 새 미완료 카드가 끼면 완료 순서가 깨진다")
  void replaceStep_rejectsCompletedCard() {
    Routine routine = routine(2);
    routine.getSteps().get(0).setCompleted(true);
    when(routineRepository.findById("routine-1")).thenReturn(Optional.of(routine));

    assertThatThrownBy(() -> cardSplitStepWriter.replaceStep(
      GUARDIAN, "routine-1", "step-1", TWO_CARDS, List.of("a", "b")))
      .extracting("errorCode").isEqualTo(ErrorCode.ROUTINE_STEP_ALREADY_COMPLETED);
  }

  @Test
  @DisplayName("없는 카드는 404 ROUTINE_STEP_NOT_FOUND")
  void replaceStep_unknownStep() {
    Routine routine = routine(2);
    when(routineRepository.findById("routine-1")).thenReturn(Optional.of(routine));

    assertThatThrownBy(() -> cardSplitStepWriter.replaceStep(
      GUARDIAN, "routine-1", "step-9", TWO_CARDS, List.of("a", "b")))
      .extracting("errorCode").isEqualTo(ErrorCode.ROUTINE_STEP_NOT_FOUND);
  }

  @Test
  @DisplayName("읽기도 카드 수정과 같은 권한 검사를 거친다")
  void readSource_checksEditPermission() {
    Routine routine = routine(2);
    when(routineRepository.findById("routine-1")).thenReturn(Optional.of(routine));

    CardSplitStepWriter.SplitSource source = cardSplitStepWriter.readSource(GUARDIAN, "routine-1", "step-2");

    assertThat(source.title()).isEqualTo("제목 2");
    verify(profileAccessGuard).checkRoutine(GUARDIAN, "profile-1", "member-1", ProfileAccessGuard.RoutineAction.EDIT);
  }

  private static Routine routine(int stepCount) {
    Profile profile = new Profile();
    profile.setId("profile-1");
    profile.setNickname("하늘");
    Routine routine = new Routine();
    routine.setId("routine-1");
    routine.setProfile(profile);
    routine.setStatus(RoutineStatus.CONFIRMED);
    routine.setCreatedBy("member-1");
    List<RoutineStep> steps = new ArrayList<>();
    for (int index = 1; index <= stepCount; index++) {
      RoutineStep step = new RoutineStep();
      step.setId("step-" + index);
      step.setStepOrder(index);
      step.setTitle("제목 " + index);
      step.setDescription("단계 " + index);
      step.setCompleted(false);
      steps.add(step);
    }
    routine.setSteps(steps);
    return routine;
  }
}
