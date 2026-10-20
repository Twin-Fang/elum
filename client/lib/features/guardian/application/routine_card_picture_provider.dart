import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/card_image_repository.dart';

/// 일과 카드 그림 조회 열쇠: imagePath 는 캐시 열쇠의 일부 (사진을 바꾸면 값이 바뀐다)
typedef RoutineCardPictureKey = ({
  String routineId,
  String stepId,
  String? imagePath,
});

/// 일과 카드 한 장의 그림 바이트 (없거나 실패면 null, 던지지 않음)
/// 다른 기능이 data 계층을 직접 부르지 않고 내 일과 카드 그림을 그릴 때 쓰는 입구
final routineCardPictureProvider = FutureProvider.autoDispose
    .family<Uint8List?, RoutineCardPictureKey>(
      (ref, key) => ref.watch(cardImageProvider(key).future),
    );
