import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/l10n_context.dart';
import '../../../core/widgets/elum_toast.dart';
import '../application/added_card_image_watcher.dart';
import '../application/routine_notifier.dart';
import '../domain/added_card_image_state.dart';

/// 카드확인: 그림을 못 붙인 카드 안내 (카드 추가 #868, 일과 만들기 #1178)
/// 카드 추가: 그리는 중 > 기다렸다 반영, 못 그림 > 아래 토스트, 기본 그림 > 아무것도 안 함
/// 일과 만들기: AI 그림 못 그린 카드 있음 > 첫 화면에 토스트 1번
mixin CardReviewAddedImage<T extends ConsumerStatefulWidget>
    on ConsumerState<T> {
  late final _imageWatcher = AddedCardImageWatcher(
    fetchImagePath: ref.read(routineFlowProvider.notifier).fetchStepImagePath,
    onImageReady: (stepId, imagePath) {
      if (!mounted) return;
      // 직접 추가한 카드 그림은 AI 가 그림
      ref.read(routineFlowProvider.notifier).applyStepImage(stepId, imagePath, isAiPicture: true);
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

  /// 방금 만든 일과에 AI 그림 못 그린 카드가 있으면 안내 1번 (첫 프레임 뒤 호출)
  void showMissingAiImageNoticeIfPending() {
    if (!mounted) return;
    final flow = ref.read(routineFlowProvider.notifier);
    if (!ref.read(routineFlowProvider).hasPendingMissingAiImageNotice) return;
    // 띄우기 전에 지움 (토스트 자리가 없어도 다시 시도하지 않음)
    flow.markMissingAiImageNoticeShown();
    showElumToast(context, context.l10n.cardImageMissingAfterCreateToast);
  }

  @override
  void dispose() {
    _imageWatcher.dispose();
    super.dispose();
  }
}
