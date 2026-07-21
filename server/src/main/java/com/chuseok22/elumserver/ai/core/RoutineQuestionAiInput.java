package com.chuseok22.elumserver.ai.core;

// GEMINI_ROUTINE_QUESTION_PREFIX 시스템 프롬프트가 기대하는 User Content 형식.
public record RoutineQuestionAiInput(String task, String routineText, ChildProfileInput childProfile) {

}
