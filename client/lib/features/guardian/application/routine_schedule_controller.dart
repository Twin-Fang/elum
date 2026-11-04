import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/dio_provider.dart';
import '../../../core/network/app_failure.dart';
import '../../member/application/plan_access.dart';
import '../data/routine_schedule_api.dart';
import '../domain/routine_schedule.dart';
import 'routine_providers.dart';

final routineScheduleApiProvider = Provider<RoutineScheduleApi>(
  (ref) => RoutineScheduleApi(ref.watch(dioProvider)),
);

/// 주간 계획 (#782). 실패하면 [AppFailure] 를 던져 화면이 다시 시도 안내를 그린다
///
/// Free 여도 받는다 — Pro 가 끝나 멈춘 예약이 있으면 그 사실을 보호자 화면에 알려야 한다.
final routineSchedulePlanProvider = FutureProvider<RoutineSchedulePlan>((
  ref,
) async {
  final planAttempt = await ref.watch(routineScheduleApiProvider).fetchPlan();
  final failure = planAttempt.failure;
  if (failure != null) throw failure;
  return planAttempt.value ?? const RoutineSchedulePlan();
});

/// 보호자 화면에 요일·시각 입구를 보일지: 앱 판정 Pro, 또는 이미 정해 둔 예약이 있음(멈춤 안내용)
///
/// 결제(#1072) 전에는 Free 에게 잠긴 입구를 보이지 않는다 ([PlanAccess.canPurchasePro]).
final canShowRoutineScheduleProvider = Provider<bool>((ref) {
  final access = ref.watch(planAccessProvider);
  if (access.canScheduleRoutines || access.canPurchasePro) return true;
  final plan = ref.watch(routineSchedulePlanProvider).value;
  return plan != null && plan.schedules.isNotEmpty;
});

/// 일과 하나의 예약 (없거나 아직 못 받았으면 null)
final routineScheduleOfProvider = Provider.family<RoutineSchedule?, String>(
  (ref, routineId) =>
      ref.watch(routineSchedulePlanProvider).value?.scheduleOf(routineId),
);

final routineScheduleControllerProvider = Provider<RoutineScheduleController>(
  RoutineScheduleController.new,
);

/// 요일·시각 저장·끄기 > 성공하면 주간 계획·오늘 일과를 다시 받는다 (refreshRoutines 가 함께) (오늘 요일이면 서버가 오늘 일과를 만든다)
class RoutineScheduleController {
  RoutineScheduleController(this._ref);

  final Ref _ref;

  RoutineScheduleApi get _api => _ref.read(routineScheduleApiProvider);

  Future<AppFailure?> save(RoutineSchedule schedule) =>
      _refreshAfter(_api.save(schedule));

  Future<AppFailure?> turnOff(String routineId) =>
      _refreshAfter(_api.delete(routineId));

  Future<AppFailure?> _refreshAfter(Future<AppFailure?> call) async {
    final failure = await call;
    if (failure == null) _ref.refreshRoutines();
    return failure;
  }
}
