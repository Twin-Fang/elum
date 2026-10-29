import 'package:flutter/material.dart';

import '../../../../core/theme/theme_context_ext.dart';
import '../../../../shared/example_card_image/example_card_art.dart';
import '../../../../shared/example_card_image/example_card_image_catalog.dart';
import '../../../../shared/pictogram/pictogram_art.dart';
import '../../../../shared/pictogram/pictogram_catalog.dart';

/// 올린 그림이 없는 카드의 번들 그림: 예시 이미지 > 픽토그램 > 빈 칸
/// 칸을 꽉 채우므로 부모가 크기를 정한다
class TalkBundledCardArt extends StatelessWidget {
  const TalkBundledCardArt({
    super.key,
    required this.label,
    this.pictogramId,
    this.exampleImageId,
  });

  /// 낭독기가 그림 대신 읽을 이름 (카드 제목)
  final String label;
  final String? pictogramId;
  final String? exampleImageId;

  @override
  Widget build(BuildContext context) {
    final pictogram = PictogramCatalog.parse(pictogramId);
    final exampleImage = ExampleCardImageCatalog.parse(exampleImageId);
    Widget emptySlot(BuildContext context) =>
        ColoredBox(color: context.colors.editChipBg);
    Widget pictogramOrEmpty(BuildContext context) => pictogram == null
        ? emptySlot(context)
        : PictogramArt(id: pictogram, label: label, fallbackBuilder: emptySlot);
    if (exampleImage == null) return pictogramOrEmpty(context);
    return ExampleCardArt(
      id: exampleImage,
      label: label,
      fallbackBuilder: pictogramOrEmpty,
    );
  }
}
