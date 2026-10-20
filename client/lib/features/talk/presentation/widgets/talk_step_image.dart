import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_motion.dart';
import '../../../../core/theme/theme_context_ext.dart';
import '../../../../shared/example_card_image/example_card_art.dart';
import '../../../../shared/example_card_image/example_card_image_catalog.dart';
import '../../../../shared/pictogram/pictogram_art.dart';
import '../../../../shared/pictogram/pictogram_catalog.dart';
import '../../application/talk_step_image_provider.dart';
import '../../domain/talk_post.dart';

/// 글 카드 한 장의 그림: 올린 그림 > 예시 이미지 > 픽토그램 > 빈 칸
/// 흐리게 올린 그림은 서버가 이미 흐리게 만들어 보내므로 앱은 가공하지 않음
/// 칸을 꽉 채우므로 부모가 크기를 정한다
class TalkStepImage extends ConsumerWidget {
  const TalkStepImage({super.key, required this.postId, required this.step});

  final String postId;
  final TalkStep step;

  /// 올린 그림이 없을 때 자리를 채운다: 예시 이미지 > 픽토그램 > 빈 칸
  Widget _bundledArtOrEmpty(BuildContext context) {
    final label = step.title ?? '';
    final pictogram = PictogramCatalog.parse(step.pictogramId);
    final exampleImage = ExampleCardImageCatalog.parse(step.exampleImageId);
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

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // 올린 그림이 없는 카드는 서버에 묻지 않는다
    if (!step.hasImage) return _bundledArtOrEmpty(context);

    final imageAsync = ref.watch(
      talkStepImageProvider((postId: postId, stepOrder: step.stepOrder)),
    );
    final child = switch (imageAsync) {
      // 받는 동안은 빈 바탕만 (기본 그림이 번쩍였다 사라지지 않게)
      AsyncLoading() => ColoredBox(
        key: const ValueKey('loading'),
        color: context.colors.editChipBg,
      ),
      AsyncData(value: final bytes?) => SizedBox.expand(
        key: ValueKey('ready|$postId|${step.stepOrder}'),
        child: Image.memory(
          bytes,
          fit: BoxFit.cover,
          // 깨진 바이트도 앱을 죽이지 않고 번들 그림으로 대체
          errorBuilder: (context, _, _) => _bundledArtOrEmpty(context),
        ),
      ),
      _ => KeyedSubtree(
        key: const ValueKey('fallback'),
        child: _bundledArtOrEmpty(context),
      ),
    };
    return AnimatedSwitcher(duration: AppMotion.fast, child: child);
  }
}
