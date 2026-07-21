package com.chuseok22.elumserver.ai.core;

import java.util.List;

public record RoutineStepDraft(String title, List<StepDraft> steps) {

  public record StepDraft(Integer order, String description) {

  }
}
