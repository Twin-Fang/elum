package com.chuseok22.elumserver.routine.core;

/// 일과 하나의 수정 찾기 진행: PENDING 찾는 중 / DONE 끝 / FAILED AI 실패 (다시 찾지 않음)
public enum RoutineMemoryExtractionState {
  PENDING,
  DONE,
  FAILED
}
