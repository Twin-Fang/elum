package com.chuseok22.elumserver.ai.core;

import java.util.List;

public record RoutineQuestionDraft(List<QuestionItem> questions) {

  public record QuestionItem(String question, List<String> options) {

  }
}
