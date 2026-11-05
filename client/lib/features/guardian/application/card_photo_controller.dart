import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../credit/application/credit_summary_refresh.dart';
import '../data/card_image_candidate_api.dart';
import '../data/card_image_repository.dart';
import '../data/card_photo.dart';
import '../domain/image_redraw_hint.dart';

final cardPhotoControllerProvider =
    Provider<CardPhotoController>((ref) => CardPhotoController(ref));

/// 카드 그림 바꾸기(사진 올리기 · AI 그림 새로 그리기 · 후보 고르기)가 쓰는 저장소 호출을 모았다.
class CardPhotoController {
  CardPhotoController(this._ref);

  final Ref _ref;

  Future<PhotoUploadResult> uploadPhoto({
    required String routineId,
    required String stepId,
    required PickedPhoto photo,
  }) => _ref.read(cardImageRepositoryProvider).uploadPhoto(
    routineId: routineId,
    stepId: stepId,
    photo: photo,
  );

  /// 새 그림 후보 그리기 > 성공·실패 모두 크레딧 잔액·무료 횟수 다시 받기 (예약·정산·반환이 일어났을 수 있음)
  Future<CardCandidateDrawResult> drawCandidate({
    required String routineId,
    required String stepId,
    required CardRedrawRequest request,
  }) async {
    final drawResult = await _ref.read(cardImageCandidateApiProvider).drawCandidate(
      routineId: routineId,
      stepId: stepId,
      request: request,
    );
    refreshCreditSummary(_ref);
    return drawResult;
  }

  Future<Uint8List?> fetchCandidateImage({required String routineId, required String stepId}) =>
      _ref.read(cardImageCandidateApiProvider).fetchCandidateImage(routineId: routineId, stepId: stepId);

  Future<CardImageApplyResult> applyCandidate({
    required String routineId,
    required String stepId,
    required String candidateImagePath,
  }) => _ref.read(cardImageCandidateApiProvider).applyCandidate(
    routineId: routineId,
    stepId: stepId,
    candidateImagePath: candidateImagePath,
  );

  Future<void> discardCandidate({required String routineId, required String stepId}) =>
      _ref.read(cardImageCandidateApiProvider).discardCandidate(routineId: routineId, stepId: stepId);
}
