import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/models/routine.dart';
import 'routine_providers.dart';

/// 끝낸 일과 축하 내용: 그날 끝낸 일과들 (알림의 일과가 맨 앞) + 받은 별 수 (끝낸 카드 1장 = 별 1개)
@immutable
class RoutineDoneSummary {
  const RoutineDoneSummary({required this.finishedRoutines, required this.starCount});

  final List<Routine> finishedRoutines;
  final int starCount;
}

/// 일과 id > 축하 내용 (오늘 · 지난 목록에서 찾음, 새 API 없음)
/// 상태 4가지: 불러오는 중 · 실패 (찾기 전에 목록 실패) · 없음 (data null, 지워진 일과) · 내용
final routineDoneSummaryProvider = Provider.autoDispose.family<AsyncValue<RoutineDoneSummary?>, String>((
  ref,
  routineId,
) {
  final todayAsync = ref.watch(todayRoutinesProvider);
  final todayRoutines = todayAsync.value;
  final targetToday = todayRoutines?.where((routine) => routine.id == routineId).firstOrNull;
  // 오늘 일과면 그날 끝낸 다른 일과도 함께 (완료 알림은 이룸이 · 날짜별 한 줄로 묶임)
  if (todayRoutines != null && targetToday != null) {
    final othersFinished = todayRoutines.where((routine) => routine.id != routineId && routine.isFinished);
    return AsyncData(_summaryOf([targetToday, ...othersFinished]));
  }

  final pastAsync = ref.watch(pastRoutinesProvider);
  final targetPast = pastAsync.value?.where((routine) => routine.id == routineId).firstOrNull;
  if (targetPast != null) return AsyncData(_summaryOf([targetPast]));

  // 못 찾음: 목록 하나라도 실패면 실패, 아직 받는 중이면 로딩, 둘 다 받았으면 없음
  final listError = todayRoutines == null ? todayAsync.error : (pastAsync.value == null ? pastAsync.error : null);
  if (listError != null) return AsyncError(listError, StackTrace.current);
  if (todayRoutines == null || pastAsync.value == null) return const AsyncLoading();
  return const AsyncData(null);
});

RoutineDoneSummary _summaryOf(List<Routine> finishedRoutines) => RoutineDoneSummary(
  finishedRoutines: finishedRoutines,
  starCount: finishedRoutines.fold(0, (sum, routine) => sum + _completedStepCountOf(routine)),
);

/// 끝낸 카드 수: 서버 계산값 우선, 없으면 카드 표시로 셈
int _completedStepCountOf(Routine routine) {
  if (routine.completedStepCount > 0) return routine.completedStepCount;
  return routine.steps.where((step) => step.completed).length;
}
