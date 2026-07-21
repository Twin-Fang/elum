package com.chuseok22.elumserver.ai.core;

import java.util.List;

// GEMINI_ROUTINE_REVISE_PREFIX 시스템 프롬프트가 기대하는 User Content 형식.
// PreviousRoutineInput.steps는 RoutineStepDraft.StepDraft(order, description)를 그대로
// 재사용한다 — 같은 ai/core 패키지 안에서 구조가 완전히 같은 타입을 중복 정의하지 않는다.
public record RoutineReviseAiInput(
  String task,
  PreviousRoutineInput previousRoutine,
  String feedback,
  ChildProfileInput childProfile
) {

  public record PreviousRoutineInput(String title, List<RoutineStepDraft.StepDraft> steps) {

  }
}
