package com.chuseok22.elumserver.routine.application.service;

import com.chuseok22.elumserver.routine.infrastructure.entity.Routine;
import java.util.ArrayList;
import java.util.List;

/// 같은 원본에서 보낸 일과 묶음 (시간 오름차순으로 더함, 제목은 가장 최근 것)
final class WeeklyReportRoutineGroup {

  final List<Routine> routines = new ArrayList<>();
  String title;
  int sentCount;
  int completedCount;

  void add(Routine routine) {
    routines.add(routine);
    title = routine.getTitle();
    sentCount++;
    if (WeeklyReportAggregator.isCompleted(routine)) {
      completedCount++;
    }
  }
}
