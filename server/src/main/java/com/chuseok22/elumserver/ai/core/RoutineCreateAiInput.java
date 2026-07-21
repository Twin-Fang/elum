package com.chuseok22.elumserver.ai.core;

import java.util.List;

// GEMINI_ROUTINE_CREATE_PREFIX 시스템 프롬프트가 기대하는 User Content 형식. 필드 이름은
// 프롬프트 본문의 [입력 형식] 절과 정확히 일치해야 한다.
public record RoutineCreateAiInput(
  String task,
  String routineText,
  ChildProfileInput childProfile,
  List<String> additionalAnswers
) {

}
