package com.chuseok22.elumserver.routine.infrastructure.constant;

import java.time.LocalTime;
import java.util.List;

/**
 * 예시 일과 1개: 분류, 제목(다섯 언어), 오늘 예정 시각, 카드 목록
 */
public record RoutineExample(
  RoutineExampleCategory category,
  LocalizedText title,
  LocalTime scheduledTime,
  List<RoutineExampleStep> steps
) {

}
