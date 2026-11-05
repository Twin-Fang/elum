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

/// 일과 하나의 인쇄 준비 결과: 카드 순서대로 그림 + 그림을 받지 못한 카드
///
/// 못 받은 카드는 예시 > 픽토그램 > 제목만 순서로 대신 채워 두므로 내보내기는 막지 않는다
@immutable
class CardExportPictures {
  const CardExportPictures({required this.byCardId, this.failedCardIds = const {}});

  final Map<String, CardExportPicture> byCardId;

  /// 서버에 그림이 있다는데(`imagePath`) 받지 못한 카드 id. 종이 밖 한 줄 안내 + 다시 받기 대상
  final Set<String> failedCardIds;

  int get failedCount => failedCardIds.length;

  CardExportPicture of(ActionCard card) =>
      byCardId[card.id] ?? const CardExportPicture.none();

  bool get hasPictogram => byCardId.values.any((p) => p.pictogramId != null);

  /// 원래 그림이 없는 카드가 있는가 (못 받은 카드는 따로 안내하므로 뺌)
  bool get hasMissingPicture => byCardId.entries
      .any((entry) => !entry.value.hasPicture && !failedCardIds.contains(entry.key));
}

/// 일과의 카드 그림을 전부 받아 둔다 (인쇄물은 다 받은 뒤에 굽는다 — 덜 받은 채 구우면 빈 칸이 찍힘)
final cardExportPicturesProvider = FutureProvider.autoDispose
    .family<CardExportPictures, Routine>((ref, routine) async {
      final byCardId = <String, CardExportPicture>{};
      final failedCardIds = <String>{};
      for (final card in routine.steps) {
        final downloaded = await _downloadPicture(ref, routine.id, card);
        if (downloaded != null) {
          byCardId[card.id] = CardExportPicture.downloaded(downloaded);
          continue;
        }
        // 서버에 그림이 있다는데 못 받았으면 실패로 센다 (그림이 원래 없는 카드와 구분)
        if (card.imagePath != null && canFetchCardImage(routine.id, card.id)) {
          failedCardIds.add(card.id);
        }
        byCardId[card.id] = _bundledPictureOf(card);
      }
      return CardExportPictures(byCardId: byCardId, failedCardIds: failedCardIds);
    });

/// 못 받은 카드 그림 다시 받기: 실패한 카드 그림 > 인쇄 준비 결과 순서로 새로 부름
///
/// 카드 그림 provider 는 일과 화면과 함께 쓰여 실패 값이 남아 있을 수 있어 그것부터 버림
void retryCardExportPictures(WidgetRef ref, Routine routine, CardExportPictures pictures) {
  for (final card in routine.steps) {
    if (!pictures.failedCardIds.contains(card.id)) continue;
    ref.invalidate(
      cardImageProvider((routineId: routine.id, stepId: card.id, imagePath: card.imagePath)),
    );
  }
  ref.invalidate(cardExportPicturesProvider(routine));
}

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
