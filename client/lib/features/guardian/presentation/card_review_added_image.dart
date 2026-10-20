import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/l10n_context.dart';
import '../../../core/widgets/elum_toast.dart';
import '../application/added_card_image_watcher.dart';
import '../application/routine_notifier.dart';
import '../domain/added_card_image_state.dart';

/// 카드확인: 직접 추가한 카드의 그림 따라가기 (#868)
/// 그리는 중 > 기다렸다 반영, 못 그림 > 아래 토스트, 기본 그림 > 아무것도 안 함
mixin CardReviewAddedImage<T extends ConsumerStatefulWidget>
    on ConsumerState<T> {
  late final _imageWatcher = AddedCardImageWatcher(
    fetchImagePath: ref.read(routineFlowProvider.notifier).fetchStepImagePath,
    onImageReady: (stepId, imagePath) {
      if (!mounted) return;
      ref.read(routineFlowProvider.notifier).applyStepImage(stepId, imagePath);
      setState(() {});
    },
    onGaveUp: (_) {
      if (!mounted) return;
      setState(() {});
      showElumToast(context, context.l10n.cardImageUnavailableToast);
    },
  );

  /// 이 카드 그림을 서버가 그리는 중인가
  bool isAddedCardImageGenerating(String stepId) =>
      _imageWatcher.isWaiting(stepId);

  /// 카드 추가 결과의 그림 상태별 처리
  void followAddedCardImage(String? stepId, AddedCardImageState imageState) {
    if (!mounted) return;
    switch (imageState) {
      case AddedCardImageState.generating:
        if (stepId != null) setState(() => _imageWatcher.watch(stepId));
      case AddedCardImageState.creditInsufficient:
        showElumToast(context, context.l10n.cardImageNoCreditToast);
      case AddedCardImageState.unavailable:
        showElumToast(context, context.l10n.cardImageUnavailableToast);
      case AddedCardImageState.basicPictogramStyle:
      case AddedCardImageState.notRequested:
        break;
    }
  }

  @override
  void dispose() {
    _imageWatcher.dispose();
    super.dispose();
  }
}
