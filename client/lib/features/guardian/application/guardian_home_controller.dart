import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/app_failure.dart';
import '../../../shared/models/routine.dart';
import 'routine_providers.dart';

final guardianHomeControllerProvider =
    Provider<GuardianHomeController>((ref) => GuardianHomeController(ref));

/// 보호자 홈의 오늘 일과 목록과 일과 상세 시트가 쓰는 일과 저장소 호출을 모았다.
class GuardianHomeController {
  GuardianHomeController(this._ref);

  final Ref _ref;

  Future<AppFailure?> reorder(List<String> routineIds) =>
      _ref.read(routineRepositoryProvider).reorder(routineIds);

  Future<AppFailure?> reorderSteps(String routineId, List<String> stepIds) =>
      _ref.read(routineRepositoryProvider).reorderSteps(routineId, stepIds);

  Future<AppFailure?> delete(String routineId) =>
      _ref.read(routineRepositoryProvider).delete(routineId);

  Future<Attempt<Routine>> duplicate(String routineId) =>
      _ref.read(routineRepositoryProvider).duplicate(routineId);
}
