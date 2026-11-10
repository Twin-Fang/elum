package com.chuseok22.elumserver.routine.core;

/// AI 가 만든 일과를 보호자가 확정함: 커밋 뒤 비동기로 그 일과 하나의 수정을 찾음
public record RoutineMemoryExtractionRequestedEvent(String routineId) {

}
