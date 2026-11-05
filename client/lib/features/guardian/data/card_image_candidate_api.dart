import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/dio_provider.dart';
import '../../../core/logger/app_logger.dart';
import '../../../core/network/app_failure.dart';
import '../../../shared/models/action_card.dart';
import '../domain/image_redraw_hint.dart';

/// 카드 AI 그림 새로 그리기 · 고르기 API (서버 `RoutineStepImageDocs`)
///
/// 그리기 > 후보 받기 > 바꾸기 또는 버리기. 그리기만으로는 카드 그림이 바뀌지 않는다 (이룸이는 고른 그림만 봄).
/// **절대 throw 하지 않는다.** 실패는 서버 코드가 든 [AppFailure] 로 돌려준다.
class CardImageCandidateApi {
  CardImageCandidateApi(this._dio);

  final Dio _dio;

  static String _base(String routineId, String stepId) => '/api/routines/$routineId/steps/$stepId/image';

  /// 새 그림 후보 그리기 (`POST .../image/regenerate`, 수 초). 다시 그리기·처음 그리기 모두
  Future<CardCandidateDrawResult> drawCandidate({
    required String routineId,
    required String stepId,
    required CardRedrawRequest request,
  }) async {
    final requestText = request.requestText.trim();
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        '${_base(routineId, stepId)}/regenerate',
        data: {
          if (requestText.isNotEmpty) 'requestText': requestText,
          if (request.hints.isNotEmpty) 'hints': [for (final hint in request.hints) hint.apiValue],
        },
      );
      final candidate = CardImageCandidate.tryParse(response.data);
      // 후보 열쇠가 없으면 고를 수 없다 — 성공으로 착각하지 않는다
      if (candidate == null) return const CardCandidateDrawResult.failed(AppFailure(fault: NetworkFault.app));
      return CardCandidateDrawResult.ok(candidate);
    } catch (e) {
      AppLogger.error('card', '그림 후보 그리기 실패: $e');
      return CardCandidateDrawResult.failed(AppFailure.of(e));
    }
  }

  /// 후보 그림 바이트 (`GET .../image/candidate`). 실패하면 null
  Future<Uint8List?> fetchCandidateImage({required String routineId, required String stepId}) async {
    try {
      final response = await _dio.get<List<int>>(
        '${_base(routineId, stepId)}/candidate',
        options: Options(responseType: ResponseType.bytes),
      );
      final bytes = response.data;
      if (bytes == null || bytes.isEmpty) return null;
      return Uint8List.fromList(bytes);
    } catch (e) {
      AppLogger.error('card', '그림 후보 받기 실패: $e');
      return null;
    }
  }

  /// 새 그림으로 바꾸기 (`POST .../image/candidate/apply`). 200 은 바뀐 카드 한 장
  Future<CardImageApplyResult> applyCandidate({
    required String routineId,
    required String stepId,
    required String candidateImagePath,
  }) async {
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        '${_base(routineId, stepId)}/candidate/apply',
        data: {'candidateImagePath': candidateImagePath},
      );
      final body = response.data;
      final card = body == null ? null : ActionCard.fromJson(body);
      if (card == null || card.imagePath == null || card.imagePath!.isEmpty) {
        return const CardImageApplyResult.failed(AppFailure(fault: NetworkFault.app));
      }
      return CardImageApplyResult.ok(card);
    } catch (e) {
      AppLogger.error('card', '새 그림 바꾸기 실패: $e');
      return CardImageApplyResult.failed(AppFailure.of(e));
    }
  }

  /// 원래 그림 그대로 (`DELETE .../image/candidate`). 실패해도 카드 그림은 그대로라 로그만 (다음 그리기가 덮음)
  Future<void> discardCandidate({required String routineId, required String stepId}) async {
    try {
      await _dio.delete<void>('${_base(routineId, stepId)}/candidate');
    } catch (e) {
      AppLogger.error('card', '그림 후보 버리기 실패: $e');
    }
  }
}

/// 고르기 전 새 그림 후보: 서버 `RoutineStepImageCandidateResponse`
@immutable
class CardImageCandidate {
  const CardImageCandidate({required this.candidateImagePath, required this.isFirstPicture});

  /// 고를 때 그대로 보내는 열쇠
  final String candidateImagePath;

  /// AI 그림이 없던 카드에 처음 그렸는가 (원래 자리는 픽토그램)
  final bool isFirstPicture;

  /// 응답 > 후보. 열쇠가 없으면 null
  static CardImageCandidate? tryParse(Object? raw) {
    if (raw is! Map) return null;
    final key = raw['candidateImagePath'];
    if (key is! String || key.isEmpty) return null;
    return CardImageCandidate(candidateImagePath: key, isFirstPicture: raw['isFirstPicture'] == true);
  }
}

/// 후보 그리기 결과: 후보 또는 실패
@immutable
class CardCandidateDrawResult {
  const CardCandidateDrawResult.ok(CardImageCandidate this.candidate) : failure = null;
  const CardCandidateDrawResult.failed(AppFailure this.failure) : candidate = null;

  final CardImageCandidate? candidate;
  final AppFailure? failure;
}

/// 새 그림으로 바꾸기 결과: 바뀐 카드 또는 실패
@immutable
class CardImageApplyResult {
  const CardImageApplyResult.ok(ActionCard this.card) : failure = null;
  const CardImageApplyResult.failed(AppFailure this.failure) : card = null;

  final ActionCard? card;
  final AppFailure? failure;
}

final cardImageCandidateApiProvider = Provider<CardImageCandidateApi>(
  (ref) => CardImageCandidateApi(ref.watch(dioProvider)),
);
