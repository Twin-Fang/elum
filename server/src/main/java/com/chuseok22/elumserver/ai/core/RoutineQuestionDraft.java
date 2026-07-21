package com.chuseok22.elumserver.ai.core;

import java.util.List;

public record RoutineQuestionDraft(List<QuestionItem> questions) {

  public record QuestionItem(String supportGoal, String question, List<Option> options) {

    public record Option(String emoji, String label) {

    }
  }
}
