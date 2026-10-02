package com.chuseok22.elumserver.routine.application.dto.response;

import static org.assertj.core.api.Assertions.assertThat;

import com.chuseok22.elumserver.common.locale.AppLocale;
import com.chuseok22.elumserver.member.application.service.Caller;
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

  @Test
  @DisplayName("단계 응답은 pictogramId 를 그대로 싣고, 없으면 null 이다 (#247)")
  void stepResponse_carriesPictogramId() {
    RoutineStep withPictogram = new RoutineStep();
    withPictogram.setStepOrder(1);
    withPictogram.setDescription("d");
    withPictogram.setPictogramId("get_dressed_,_to");
    RoutineStep without = new RoutineStep();
    without.setStepOrder(2);
    without.setDescription("d");

    assertThat(RoutineStepResponse.from(withPictogram).pictogramId()).isEqualTo("get_dressed_,_to");
    assertThat(RoutineStepResponse.from(without).pictogramId()).isNull();
  }

  @Test
  @DisplayName("응답은 일과의 언어를 코드 문자열로 싣는다 — 기존 일과(기본값)는 ko")
  void from_carriesLanguageCode() {
    Routine routine = new Routine();
    routine.setId("routine-1");
    routine.setTitle("병원 다녀오기");
    routine.setRawInputText("raw");
    routine.setSanitizedInputText("sanitized");
    routine.setStatus(RoutineStatus.CONFIRMED);
    routine.setSteps(List.of());

    assertThat(RoutineResponse.from(routine).language()).isEqualTo("ko");

    routine.setLanguage(AppLocale.JA);
    assertThat(RoutineResponse.from(routine).language()).isEqualTo("ja");
  }

  @Test
  @DisplayName("언어가 null 인 행(마이그레이션 전 코드·픽스처)도 응답 변환이 죽지 않고 ko 로 떨어진다")
  void from_nullLanguage_fallsBackToKo() {
    Routine routine = new Routine();
    routine.setId("routine-1");
    routine.setTitle("제목");
    routine.setStatus(RoutineStatus.CONFIRMED);
    routine.setSteps(List.of());
    routine.setLanguage(null);

    RoutineResponse base = RoutineResponse.from(routine);

    assertThat(base.language()).isEqualTo("ko");
    assertThat(base.withCredit(new RoutineResponse.CreditUsage(1, 1, 1, 1)).language()).isEqualTo("ko");
  }

  @Test
  @DisplayName("언어는 응답을 가공하는 다섯 메서드(withCreatedByMe 는 forCaller 경유)를 거쳐도 그대로다")
  void language_survivesEveryTransformation() {
    Routine routine = new Routine();
    routine.setId("routine-1");
    routine.setTitle("제목");
    routine.setRawInputText("raw");
    routine.setSanitizedInputText("sanitized");
    routine.setStatus(RoutineStatus.CONFIRMED);
    routine.setCreatedBy("member-1");
    routine.setSteps(List.of());
    routine.setLanguage(AppLocale.ES);
    RoutineResponse base = RoutineResponse.from(routine);

    assertThat(base.language()).isEqualTo("es");
    assertThat(base.withCredit(new RoutineResponse.CreditUsage(1, 1, 1, 1)).language()).isEqualTo("es");
    assertThat(base.withImageSkippedReason("AI_CREDIT_INSUFFICIENT").language()).isEqualTo("es");
    assertThat(base.withoutSourceText().language()).isEqualTo("es");
    assertThat(base.withCreatorName("엄마").language()).isEqualTo("es");
    assertThat(base.forCaller(Caller.guardian("member-1")).language()).isEqualTo("es");
    assertThat(base.forCaller(Caller.guardian("someone-else")).language()).isEqualTo("es");
  }
}
