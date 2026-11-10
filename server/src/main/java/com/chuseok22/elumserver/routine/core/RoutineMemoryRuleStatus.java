package com.chuseok22.elumserver.routine.core;

/// 규칙 상태: ACTIVE 일과 만들 때 적용 / WATCHING 관찰 중(적용 안 함) / OFF 보호자가 끔
public enum RoutineMemoryRuleStatus {
  ACTIVE,
  WATCHING,
  OFF
}
