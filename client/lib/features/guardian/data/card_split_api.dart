import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/dio_provider.dart';
import '../../../core/logger/app_logger.dart';
import '../../../core/network/app_failure.dart';
import '../../../shared/models/routine.dart';
import '../domain/card_split.dart';

final cardSplitApiProvider = Provider<CardSplitApi>((ref) => CardSplitApi(ref.watch(dioProvider)));

/// 카드 나누기 서버 호출 (`RoutineCardSplitDocs`): 안 받기(저장 없음) > 적용
/// 절대 throw 하지 않고 서버 코드가 든 [AppFailure] 로 돌려줌
class CardSplitApi {
  CardSplitApi(this._dio);

  final Dio _dio;

  static String _base(String routineId, String stepId) => '/api/routines/$routineId/steps/$stepId';

  /// 안 받기 (`POST .../split-suggestion`, 수 초). 크레딧을 쓰지 않음
  Future<({CardSplitSuggestion? suggestion, AppFailure? failure})> suggest({
    required String routineId,
    required String stepId,
  }) async {
    AppLogger.repositoryCall('CardSplitApi', 'suggest', {'routineId': routineId, 'stepId': stepId});
    try {
      final response = await _dio.post<Map<String, dynamic>>('${_base(routineId, stepId)}/split-suggestion');
      final suggestion = _readSuggestion(response.data);
      // 모양이 어긋난 응답은 안이 없는 것으로 보고 실패 처리 (빈 안을 그리지 않음)
      if (suggestion == null) return (suggestion: null, failure: const AppFailure(fault: NetworkFault.app));
      return (suggestion: suggestion, failure: null);
    } catch (e) {
      AppLogger.repositoryError('CardSplitApi', 'suggest', e);
      return (suggestion: null, failure: AppFailure.of(e));
    }
  }

  /// 안 적용 (`POST .../split`): 원래 카드가 그 자리에서 [drafts] 로 바뀐 일과를 돌려줌
  Future<({Routine? routine, AppFailure? failure})> apply({
    required String routineId,
    required String stepId,
    required List<CardSplitDraft> drafts,
  }) async {
    // 카드 글은 보호자가 쓴 글에서 나온 것이라 로그에는 장수만 (docs 원칙 5번)
    AppLogger.repositoryCall('CardSplitApi', 'apply', {
      'routineId': routineId,
      'stepId': stepId,
      'cardCount': drafts.length,
    });
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        '${_base(routineId, stepId)}/split',
        data: {'cards': [for (final draft in drafts) draft.toJson()]},
      );
      final body = response.data;
      if (body == null) return (routine: null, failure: const AppFailure(fault: NetworkFault.app));
      return (routine: Routine.fromJson(body), failure: null);
    } catch (e) {
      AppLogger.repositoryError('CardSplitApi', 'apply', e);
      return (routine: null, failure: AppFailure.of(e));
    }
  }

  /// `{status, cards}` > 안. SUGGESTED 인데 카드가 2~3장이 아니면 null
  static CardSplitSuggestion? _readSuggestion(Map<String, dynamic>? body) {
    switch (body?['status']) {
      case 'ALREADY_SHORT':
        return const CardSplitAlreadyShort();
      case 'SUGGESTED':
        final cards = body?['cards'];
        if (cards is! List<dynamic>) return null;
        final drafts = [for (final card in cards) ?CardSplitDraft.tryParse(card)];
        final isCountValid = drafts.length == cards.length &&
            drafts.length >= cardSplitMinimumCount &&
            drafts.length <= cardSplitMaximumCount;
        return isCountValid ? CardSplitSuggested(drafts) : null;
      default:
        return null;
    }
  }
}
