import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_motion.dart';
import '../../data/card_image_repository.dart';

/// 카드 그림 조회 상태 — 화면이 "그림이 없다"를 알아야 할 때 쓴다 (#458).
enum CardImageState {
  /// 받는 중. 아직 모른다 — 기본 카드도 그리지 않는다.
  loading,

  /// 그림이 있다.
  ready,

  /// 그림이 없다 — 저장 전 카드·서버가 못 줬다·받다가 실패했다.
  none,
}

/// 서버에 그림을 물어볼 수 있는 카드인가.
///
/// 아직 서버에 저장되지 않은 카드는 이미지도 없다. 요청 자체를 하지 않는다.
bool canFetchCardImage(String routineId, String stepId) =>
    routineId.isNotEmpty && routineId != 'local' && stepId.isNotEmpty;

/// 카드 한 장의 그림 상태를 구독한다. [CardImage]와 카드 안 배치가 **같은 값**을 본다 —
/// 각자 판정하면 그림 자리는 기본 카드인데 제목 줄은 그림이 있는 것처럼 어긋난다.
CardImageState watchCardImageState(
  WidgetRef ref, {
  required String routineId,
  required String stepId,
}) {
  if (!canFetchCardImage(routineId, stepId)) return CardImageState.none;
  return ref
      .watch(cardImageProvider((routineId: routineId, stepId: stepId)))
      .when(
        loading: () => CardImageState.loading,
        error: (_, _) => CardImageState.none,
        data: (bytes) =>
            bytes == null ? CardImageState.none : CardImageState.ready,
      );
}

/// 카드 이미지.
///
/// 서버가 AI로 만든 그림을 `GET /api/routines/{id}/steps/{stepId}/image`로 준다.
/// **인증이 필요해 `Image.network`를 쓸 수 없다** — Authorization 헤더가 붙지 않는다.
/// 그래서 바이트를 직접 받아 `Image.memory`로 그린다.
///
/// 그림이 없으면 [emptyBuilder]가 만든 **기본 카드**를 보여준다 (#458). 예전에는
/// 고양이 일러스트를 고정으로 깔았는데, 자리를 비우면 카드 비율이 무너지고 아동에게
/// 깨진 이미지 아이콘을 보여줄 수도 없지만 카드와 상관없는 고양이도 뜻을 흐렸다.
class CardImage extends ConsumerWidget {
  const CardImage({
    super.key,
    required this.routineId,
    required this.stepId,
    required this.emptyBuilder,
  });

  final String routineId;
  final String stepId;

  /// 그림이 없을 때 자리를 채울 기본 카드.
  final WidgetBuilder emptyBuilder;

  // 서버가 "4:3"으로 요청해도 Gemini가 반환하는 실제 비율이 미세하게 어긋날
  // 때가 있어, 카드 4:3 박스와 안 맞아 가장자리에 배경색 라인이 비친다.
  // 살짝 확대해 넘치는 부분을 ClipRRect(부모)로 잘라내면 오차를 흡수한다.
  static const _overscanScale = 1.03;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = watchCardImageState(
      ref,
      routineId: routineId,
      stepId: stepId,
    );

    final child = switch (state) {
      // 받는 중에는 **아무것도 그리지 않는다.** 기본 카드를 먼저 보여주면 그림이
      // 오는 카드마다 기본 카드가 번쩍였다 사라진다. 자리는 부모가 지킨다
      // (그림칸은 고정 비율이라 비어 있어도 카드가 흔들리지 않는다).
      CardImageState.loading => const SizedBox.expand(key: ValueKey('loading')),
      CardImageState.none => KeyedSubtree(
        key: const ValueKey('none'),
        child: emptyBuilder(context),
      ),
      CardImageState.ready => _Picture(
        routineId: routineId,
        stepId: stepId,
        emptyBuilder: emptyBuilder,
      ),
    };

    // 그림이 툭 나타나지 않게 부드럽게 바꾼다
    return AnimatedSwitcher(duration: AppMotion.fast, child: child);
  }
}

class _Picture extends ConsumerWidget {
  const _Picture({
    required this.routineId,
    required this.stepId,
    required this.emptyBuilder,
  });

  final String routineId;
  final String stepId;
  final WidgetBuilder emptyBuilder;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bytes = ref
        .watch(cardImageProvider((routineId: routineId, stepId: stepId)))
        .value;
    // watchCardImageState 가 ready 를 준 뒤라 bytes 는 있다. 그래도 `!` 대신 막아 둔다.
    if (bytes == null) return emptyBuilder(context);

    return Transform.scale(
      key: const ValueKey('ready'),
      scale: CardImage._overscanScale,
      child: Image.memory(
        bytes,
        key: ValueKey(stepId),
        fit: BoxFit.cover,
        // 디코딩 실패도 앱을 죽이면 안 된다 — 기본 카드로 대체한다
        errorBuilder: (context, _, _) => emptyBuilder(context),
      ),
    );
  }
}
