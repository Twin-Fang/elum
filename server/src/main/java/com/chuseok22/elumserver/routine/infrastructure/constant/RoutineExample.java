package com.chuseok22.elumserver.routine.infrastructure.constant;

import java.time.LocalTime;
import java.util.List;

/**
 * 예시 일과 1개: 분류, 제목(ko·en), 오늘 예정 시각, 카드 목록
 */
public record RoutineExample(
  RoutineExampleCategory category,
  String titleKo,
  String titleEn,
  LocalTime scheduledTime,
  List<RoutineExampleStep> steps
) {

}
