package com.chuseok22.elumserver.routine.application.dto.response;

import static org.assertj.core.api.Assertions.assertThat;

import com.chuseok22.elumserver.routine.infrastructure.entity.Routine;
import com.chuseok22.elumserver.routine.infrastructure.entity.RoutineStatus;
import com.chuseok22.elumserver.routine.infrastructure.entity.RoutineStep;
import java.util.List;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;

class RoutineResponseTest {

  @Test
  @DisplayName("일부 단계만 완료된 일과는 완료 개수/전체 개수/진행률을 정확히 계산한다")
  void from_partiallyCompletedRoutine_calculatesProgress() {
    Routine routine = new Routine();
    routine.setId("routine-1");
    routine.setTitle("병원 다녀오기");
    routine.setRawInputText("raw");
    routine.setSanitizedInputText("sanitized");
    routine.setStatus(RoutineStatus.CONFIRMED);
    RoutineStep completedStep = new RoutineStep();
    completedStep.setId("step-1");
    completedStep.setStepOrder(1);
    completedStep.setDescription("신발 신기");
    completedStep.setImagePath("path-1");
    completedStep.setCompleted(true);
    RoutineStep incompleteStep = new RoutineStep();
    incompleteStep.setId("step-2");
    incompleteStep.setStepOrder(2);
    incompleteStep.setDescription("문 열기");
    incompleteStep.setImagePath("path-2");
    incompleteStep.setCompleted(false);
    routine.setSteps(List.of(completedStep, incompleteStep));

    RoutineResponse response = RoutineResponse.from(routine);

    assertThat(response.completedStepCount()).isEqualTo(1);
    assertThat(response.totalStepCount()).isEqualTo(2);
    assertThat(response.progressPercent()).isEqualTo(50);
  }

  @Test
  @DisplayName("단계가 없는 일과는 진행률을 0으로 계산한다")
  void from_noSteps_progressIsZero() {
    Routine routine = new Routine();
    routine.setId("routine-1");
    routine.setTitle("병원 다녀오기");
    routine.setRawInputText("raw");
    routine.setSanitizedInputText("sanitized");
    routine.setStatus(RoutineStatus.PENDING_REVIEW);
    routine.setSteps(List.of());

    RoutineResponse response = RoutineResponse.from(routine);

    assertThat(response.completedStepCount()).isEqualTo(0);
    assertThat(response.totalStepCount()).isEqualTo(0);
    assertThat(response.progressPercent()).isEqualTo(0);
  }
}
