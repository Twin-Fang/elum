import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../credit/application/credit_summary_refresh.dart';
import '../data/card_image_repository.dart';
import '../data/card_photo.dart';

final cardPhotoControllerProvider =
    Provider<CardPhotoController>((ref) => CardPhotoController(ref));

/// 카드 그림 바꾸기(사진 올리기 · AI 그림 다시 그리기)가 쓰는 카드 이미지 저장소 호출을 모았다.
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

  /// 다시 그리기 > 성공·실패 모두 크레딧 잔액·무료 횟수 다시 받기 (예약·정산·반환이 일어났을 수 있음)
  Future<CardRegenerateResult> regenerateImage({
    required String routineId,
    required String stepId,
  }) async {
    final regenerateResult = await _ref.read(cardImageRepositoryProvider).regenerateImage(
      routineId: routineId,
      stepId: stepId,
    );
    refreshCreditSummary(_ref);
    return regenerateResult;
  }
}
