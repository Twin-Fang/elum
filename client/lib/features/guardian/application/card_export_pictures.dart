import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/example_card_image/example_card_image_catalog.dart';
import '../../../shared/models/action_card.dart';
import '../../../shared/models/routine.dart';
import '../../../shared/pictogram/pictogram_catalog.dart';
import '../data/card_image_repository.dart';

/// 인쇄물 카드 한 장의 그림 자리: 받은 그림 > 예시 이미지 > 픽토그램 > 없음 (앱 카드와 같은 순서)
@immutable
class CardExportPicture {
  const CardExportPicture._({this.bytes, this.exampleImageId, this.pictogramId});

  const CardExportPicture.downloaded(Uint8List bytes) : this._(bytes: bytes);
  const CardExportPicture.example(String id) : this._(exampleImageId: id);
  const CardExportPicture.pictogram(String id) : this._(pictogramId: id);
  const CardExportPicture.none() : this._();

  /// AI 그림·보호자 사진 (흑백 테마에서 회색으로 바꿀 수 있는 것)
  final Uint8List? bytes;

  /// 앱 번들 예시 이미지 id
  final String? exampleImageId;

  /// Mulberry 픽토그램 id (변형 금지 · 인쇄물에 출처 표기)
  final String? pictogramId;

  bool get hasPicture => bytes != null || exampleImageId != null || pictogramId != null;
}

/// 일과 하나의 인쇄 준비 결과: 카드 순서대로 그림 + 그림을 받지 못한 카드 수
@immutable
class CardExportPictures {
  const CardExportPictures({required this.byCardId, required this.failedCount});

  final Map<String, CardExportPicture> byCardId;

  /// 서버에 그림이 있다는데(`imagePath`) 받지 못한 카드 수. 0 이 아니면 실패로 안내
  final int failedCount;

  CardExportPicture of(ActionCard card) =>
      byCardId[card.id] ?? const CardExportPicture.none();

  bool get usesPictogram => byCardId.values.any((p) => p.pictogramId != null);

  bool get hasMissingPicture => byCardId.values.any((p) => !p.hasPicture);
}

/// 일과의 카드 그림을 전부 받아 둔다 (인쇄물은 다 받은 뒤에 굽는다 — 덜 받은 채 구우면 빈 칸이 찍힘)
final cardExportPicturesProvider = FutureProvider.autoDispose
    .family<CardExportPictures, Routine>((ref, routine) async {
      final byCardId = <String, CardExportPicture>{};
      var failedCount = 0;
      for (final card in routine.steps) {
        final downloaded = await _downloadPicture(ref, routine.id, card);
        if (downloaded != null) {
          byCardId[card.id] = CardExportPicture.downloaded(downloaded);
          continue;
        }
        // 서버에 그림이 있다는데 못 받았으면 실패로 센다 (그림이 원래 없는 카드와 구분)
        if (card.imagePath != null && canFetchCardImage(routine.id, card.id)) {
          failedCount++;
        }
        byCardId[card.id] = _bundledPictureOf(card);
      }
      return CardExportPictures(byCardId: byCardId, failedCount: failedCount);
    });

Future<Uint8List?> _downloadPicture(Ref ref, String routineId, ActionCard card) async {
  if (!canFetchCardImage(routineId, card.id)) return null;
  try {
    return await ref.watch(
      cardImageProvider(
        (routineId: routineId, stepId: card.id, imagePath: card.imagePath),
      ).future,
    );
  } on Object {
    return null;
  }
}

CardExportPicture _bundledPictureOf(ActionCard card) {
  final example = ExampleCardImageCatalog.parse(card.exampleImageId);
  if (example != null) return CardExportPicture.example(example);
  final pictogram = PictogramCatalog.parse(card.pictogramId);
  if (pictogram != null) return CardExportPicture.pictogram(pictogram);
  return const CardExportPicture.none();
}
