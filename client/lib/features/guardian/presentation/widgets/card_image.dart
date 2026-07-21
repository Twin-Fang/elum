import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../../core/assets/app_assets.dart';
import '../../../../core/config/app_config.dart';
import '../../../../core/theme/app_motion.dart';
import '../../../onboarding/domain/character.dart';
import '../../data/card_image_repository.dart';

/// 카드 이미지.
///
/// 서버가 AI로 만든 그림을 `GET /api/routines/{id}/steps/{stepId}/image`로 준다.
/// **인증이 필요해 `Image.network`를 쓸 수 없다** — Authorization 헤더가 붙지 않는다.
/// 그래서 바이트를 직접 받아 `Image.memory`로 그린다.
///
/// 실패하면 캐릭터 일러스트로 대체한다. 자리를 비우면 카드 비율이 무너지고,
/// 아동에게 깨진 이미지 아이콘을 보여줄 수는 없다.
class CardImage extends ConsumerWidget {
  const CardImage({
    super.key,
    required this.routineId,
    required this.stepId,
  });

  final String routineId;
  final String stepId;

  // 서버가 "4:3"으로 요청해도 Gemini가 반환하는 실제 비율이 미세하게 어긋날
  // 때가 있어, 카드 4:3 박스와 안 맞아 가장자리에 배경색 라인이 비친다.
  // 살짝 확대해 넘치는 부분을 ClipRRect(부모)로 잘라내면 오차를 흡수한다.
  static const _overscanScale = 1.03;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // 로컬 카드(mock)는 서버에 이미지가 없다. 요청 자체를 하지 않는다.
    final canFetch = !AppConfig.useMock &&
        routineId.isNotEmpty &&
        routineId != 'local' &&
        stepId.isNotEmpty;

    if (!canFetch) return const _Fallback();

    final image = ref.watch(
      cardImageProvider((routineId: routineId, stepId: stepId)),
    );

    return image.when(
      // 로딩 중에도 자리를 지킨다. 빈 칸이 생기면 카드가 흔들린다.
      loading: () => const _Fallback(isLoading: true),
      error: (_, _) => const _Fallback(),
      data: (bytes) => bytes == null
          ? const _Fallback()
          : AnimatedSwitcher(
              // 이미지가 툭 나타나지 않게 부드럽게 바꾼다
              duration: AppMotion.fast,
              child: Transform.scale(
                scale: _overscanScale,
                child: Image.memory(
                  bytes,
                  key: ValueKey(stepId),
                  fit: BoxFit.cover,
                  // 디코딩 실패도 앱을 죽이면 안 된다
                  errorBuilder: (_, _, _) => const _Fallback(),
                ),
              ),
            ),
    );
  }
}

/// 서버 이미지를 못 쓸 때 자리를 채운다.
class _Fallback extends StatelessWidget {
  const _Fallback({this.isLoading = false});

  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      children: [
        Opacity(
          // 로딩 중임을 은근히 드러낸다. 스피너를 띄우면 아동 화면이 산만해진다.
          opacity: isLoading ? 0.4 : 1,
          child: SvgPicture.asset(
            AppAssets.character(CardCharacter.cat),
            fit: BoxFit.contain,
          ),
        ),
      ],
    );
  }
}
