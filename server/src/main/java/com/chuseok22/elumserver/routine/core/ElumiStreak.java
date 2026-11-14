package com.chuseok22.elumserver.routine.core;

/**
 * 이룸이 연속 기록 (#1409): 이어서 일과를 마친 일수, 오늘 아직 안 마쳐 끊길 수 있는지
 * 하루 유예: 오늘 안 마쳤어도 어제까지 이어졌으면 일수 유지
 */
public record ElumiStreak(int currentStreakDays, boolean isStreakAtRiskToday) {

  public static final ElumiStreak NONE = new ElumiStreak(0, false);
}
