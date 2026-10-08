import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/app_failure.dart';
import 'routine_providers.dart';

final draftRoutinesControllerProvider =
    Provider<DraftRoutinesController>((ref) => DraftRoutinesController(ref));

/// 임시저장 일과 화면이 쓰는 일과 저장소 호출을 모았다.
class DraftRoutinesController {
  DraftRoutinesController(this._ref);

  final Ref _ref;

  Future<AppFailure?> delete(String routineId) =>
      _ref.read(routineRepositoryProvider).delete(routineId);
}
