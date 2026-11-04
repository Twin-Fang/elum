import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../guardian/application/routine_providers.dart';
import '../../guardian/domain/routine_template.dart';
import '../data/expert_routine_repository.dart';
import '../domain/expert_routine.dart';

/// 분류별 목록 (null 이면 전체). 보는 동안만 들고 있는다
final expertRoutineListProvider = FutureProvider.autoDispose
    .family<List<ExpertRoutineSummary>, RoutineTemplateCategory?>(
      (ref, category) => ref
          .watch(expertRoutineRepositoryProvider)
          .fetchList(category: category?.serverValue),
    );

/// 미리 보기 (id 별)
final expertRoutineDetailProvider = FutureProvider.autoDispose
    .family<ExpertRoutineDetail, String>(
      (ref, id) => ref.watch(expertRoutineRepositoryProvider).fetchDetail(id),
    );

final expertRoutineImportControllerProvider =
    Provider<ExpertRoutineImportController>(
      (ref) => ExpertRoutineImportController(ref),
    );

/// 가져오기: 서버 요청(크레딧 없음) > 일과 목록 다시 받기. 실패는 [AppFailure] 로 던지고 안내는 화면이 한다
class ExpertRoutineImportController {
  ExpertRoutineImportController(this._ref);

  final Ref _ref;

  Future<ExpertRoutineImportResult> importToLibrary(
    String expertRoutineId, {
    required String profileId,
  }) async {
    final imported = await _ref
        .read(expertRoutineRepositoryProvider)
        .importToLibrary(expertRoutineId, profileId: profileId);
    _ref.refreshRoutines();
    return imported;
  }
}
