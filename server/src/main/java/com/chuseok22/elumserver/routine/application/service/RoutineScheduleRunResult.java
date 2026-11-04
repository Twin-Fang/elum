package com.chuseok22.elumserver.routine.application.service;

/// 정한 시각 실행 결과 6개: 알림 보냄, 원본 없음, 알림 꺼짐, 이미 끝낸 일과, 오늘 이미 보냄, 멈춤(요금제·보호자 아님)
public enum RoutineScheduleRunResult {
  NOTIFIED,
  NO_ROUTINE,
  NOTIFY_OFF,
  ALREADY_FINISHED,
  ALREADY_NOTIFIED,
  PAUSED
}
