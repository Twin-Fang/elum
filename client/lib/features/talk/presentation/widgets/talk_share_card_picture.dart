import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_motion.dart';
import '../../../../core/theme/theme_context_ext.dart';
import '../../../../shared/models/action_card.dart';
import '../../../guardian/application/routine_card_picture_provider.dart';
import 'talk_bundled_card_art.dart';

/// 올리기 미리보기용 카드 그림: 내 일과 카드 그림 > 번들 그림
/// [isBlurred] 면 흐린 모습으로 보인다 (표시용일 뿐, 실제 블러는 서버가 사본에만 건다)
/// 칸을 꽉 채우므로 부모가 크기를 정한다
class TalkShareCardPicture extends ConsumerWidget {
  const TalkShareCardPicture({
    super.key,
    required this.routineId,
    required this.card,
    required this.label,
    this.isBlurred = false,
  });

  final String routineId;

  /// 일과관리 목록에서 못 찾았으면 null (빈 칸)
  final ActionCard? card;
  final String label;
  final bool isBlurred;

  // 얼굴·글자가 알아볼 수 없을 만큼의 표시용 블러 세기
  static const _previewBlurSigma = 14.0;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final card = this.card;
    if (card == null) return ColoredBox(color: context.colors.editChipBg);

    Widget bundledArt() => TalkBundledCardArt(
      label: label,
      pictogramId: card.pictogramId,
      exampleImageId: card.exampleImageId,
    );
    // 올린 그림이 없는 카드는 서버에 묻지 않는다
    if (card.imagePath == null) return bundledArt();

    final pictureAsync = ref.watch(
      routineCardPictureProvider((
        routineId: routineId,
        stepId: card.id,
        imagePath: card.imagePath,
      )),
    );
    // 받는 동안은 빈 바탕만 (기본 그림이 번쩍였다 사라지지 않게)
    if (pictureAsync.isLoading) {
      return ColoredBox(color: context.colors.editChipBg);
    }
    final bytes = pictureAsync.value;
    if (bytes == null) return bundledArt();

    final picture = SizedBox.expand(
      child: Image.memory(
        bytes,
        fit: BoxFit.cover,
        errorBuilder: (context, _, _) => bundledArt(),
      ),
    );
    // 흐리게 · 그대로를 바꾸면 번지듯 흐려졌다 맑아진다
    return TweenAnimationBuilder<double>(
      tween: Tween(end: isBlurred ? _previewBlurSigma : 0),
      duration: AppMotion.normal,
      curve: AppMotion.standard,
      child: picture,
      builder: (context, sigma, child) => sigma == 0
          ? child!
          : ClipRect(
              child: ImageFiltered(
                imageFilter: ImageFilter.blur(sigmaX: sigma, sigmaY: sigma),
                child: child,
              ),
            ),
    );
  }
}
