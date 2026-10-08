import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/card_image_repository.dart';
import '../data/card_photo.dart';

final cardPhotoControllerProvider =
    Provider<CardPhotoController>((ref) => CardPhotoController(ref));

/// 카드 사진 올리기가 쓰는 카드 이미지 저장소 호출을 모았다.
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
}
