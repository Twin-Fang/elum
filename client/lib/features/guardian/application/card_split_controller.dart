import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/app_failure.dart';
import '../data/card_split_api.dart';
import '../domain/card_split.dart';
import 'routine_notifier.dart';

final cardSplitControllerProvider = Provider<CardSplitController>(CardSplitController.new);

/// 카드 나누기: 안 받기 > (보호자가 고르면) 적용 > 일과 화면 상태 갱신
class CardSplitController {
  CardSplitController(this._ref);

  final Ref _ref;

  Future<({CardSplitSuggestion? suggestion, AppFailure? failure})> suggest({
    required String routineId,
    required String stepId,
  }) => _ref.read(cardSplitApiProvider).suggest(routineId: routineId, stepId: stepId);

  /// 안 적용 > 원래 카드 자리에 새 카드 끼움. 돌려줌: 새 카드 수 (실패면 failure)
  Future<({int addedCount, AppFailure? failure})> apply({
    required String routineId,
    required String stepId,
    required List<CardSplitDraft> drafts,
  }) async {
    final result = await _ref.read(cardSplitApiProvider).apply(
      routineId: routineId,
      stepId: stepId,
      drafts: drafts,
    );
    final failure = result.failure;
    final splitRoutine = result.routine;
    if (failure != null || splitRoutine == null) {
      return (addedCount: 0, failure: failure ?? const AppFailure(fault: NetworkFault.app));
    }
    final addedCount = _ref.read(routineFlowProvider.notifier).applySplitSteps(
      stepId: stepId,
      drafts: drafts,
      splitRoutine: splitRoutine,
    );
    // 서버는 나눴는데 화면에서 새 카드를 못 찾음: 일과를 다시 열면 보임 (앱 쪽 실패로 알림)
    if (addedCount == 0) return (addedCount: 0, failure: const AppFailure(fault: NetworkFault.app));
    return (addedCount: addedCount, failure: null);
  }
}
