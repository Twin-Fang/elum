import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../../core/assets/app_assets.dart';
import '../../../../core/l10n/l10n_context.dart';
import '../../../../core/theme/theme_context_ext.dart';
import '../../../../core/widgets/app_pressable.dart';
import '../../../../core/widgets/elum_dialog.dart';
import '../../../../core/widgets/elum_toast.dart';
import '../../../../core/widgets/show_failure.dart';
import '../../../../shared/models/action_card.dart';
import '../../application/routine_notifier.dart';
import '../../application/card_photo_controller.dart';
import '../../data/card_photo.dart';
import '../../data/card_photo_picker.dart';
import 'card_image.dart';
import 'card_photo_permission_screen.dart';
import 'card_photo_source_sheet.dart';
import 'card_regenerate_sheet.dart';
import 'default_card_art.dart';
import '../../../../core/widgets/elum_spinner.dart';

part 'card_photo_block_parts.dart';

/// 카드 수정 시트 안의 그림 칸 — 그림 위 `사진 바꾸기` · (AI 그림이면) `다시 그리기` 칩과 그 뒤의 모든 상태.
///
/// **임시 시안이다.** 디자이너 확정 전 제시용 목업(`opt2_A`)을 그대로 옮겼다.
///
/// 흐름: 칩 → 고르기 시트 → (카메라·갤러리) → 올리는 중 → 성공(그림 갈아 끼움) / 실패.
/// 취소는 아무 일도 없고, 권한 거부는 우회 안내, 올리는 중은 칩을 감춰 두 번 못 누르며,
/// 실패는 문구 + **에러 코드** + `다시 하기`다.
///
/// 다시 그리기: 칩 → 비용 확인 시트 → 그리는 중 → 성공(그림 갈아 끼움 + 토스트) / 실패(에러 코드 팝업, 그림 그대로).
///
/// **서버 id 가 있는 카드에서만 쓴다.** 호출부가 [routineId]·[stepId] 가 서버 것일 때만
/// 이 위젯을 놓는다 — 서버에 없는 카드는 올릴 곳이 없다.
class CardPhotoBlock extends ConsumerStatefulWidget {
  const CardPhotoBlock({
    super.key,
    required this.routineId,
    required this.stepId,
  });

  final String routineId;
  final String stepId;

  /// 칩의 누름 영역 — 테스트가 48×48 을 재는 데 쓴다.
  static const chipTapKey = ValueKey('card-photo-chip-tap');

  /// 다시 그리기 실패 팝업의 에러 코드 (서버 코드가 없을 때)
  static const regenerateErrorCode = 'E-CARD-REGENERATE';

  /// 그림 칸 높이 (목업 150).
  static const height = 150.0;

  /// 미리보기 비율 — Figma 카드 그림 칸 313×230.
  static const previewAspect = 313 / 230;

  @override
  ConsumerState<CardPhotoBlock> createState() => _CardPhotoBlockState();
}

enum _Phase { idle, uploading, regenerating, failed }

class _CardPhotoBlockState extends ConsumerState<CardPhotoBlock> {
  var _phase = _Phase.idle;
  PhotoFailure? _failure;

  /// 같은 사진으로 다시 올릴 때 쓴다. 다른 사진을 골라야 하는 실패에서는 비운다.
  PickedPhoto? _retryPhoto;

  /// 고르는 중이거나 올리는 중 — 칩·다시 하기를 또 눌러도 새 흐름이 시작되지 않는다.
  var _busy = false;

  ActionCard? _step() {
    final steps = ref.watch(routineFlowProvider).routine?.steps;
    if (steps == null) return null;
    for (final s in steps) {
      if (s.id == widget.stepId) return s;
    }
    return null;
  }

  /// 칩 → 고르기 시트 → 사진.
  Future<void> _start() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _failure = null;
      _retryPhoto = null;
      _phase = _Phase.idle;
    });
    try {
      final source = await CardPhotoSourceSheet.show(context);
      if (source == null || !mounted) return;
      await _pickAndUpload(source);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _pickAndUpload(PhotoSource source) async {
    final result = await ref.read(cardPhotoPickerProvider).pick(source);
    // 사진 앱이 떠 있는 동안 시트가 닫혔다 — 올릴 곳이 없다
    if (!mounted) return;

    switch (result) {
      case PhotoPickCancelled():
        // 그냥 돌아왔다 — 오류가 아니다
        return;
      case PhotoPickFailed(:final failure):
        setState(() {
          _phase = _Phase.failed;
          _failure = failure;
          _retryPhoto = null;
        });
      case PhotoPickDenied(:final source):
        final choice = await CardPhotoPermissionScreen.show(context, source);
        if (!mounted || choice == PhotoPermissionChoice.back) return;
        // 막힌 쪽 말고 다른 길로
        await _pickAndUpload(
          source == PhotoSource.camera
              ? PhotoSource.gallery
              : PhotoSource.camera,
        );
      case PhotoPicked(:final photo):
        await _upload(photo);
    }
  }

  Future<void> _upload(PickedPhoto photo) async {
    // await 뒤 시트가 사라져도(내려서 닫음) 끝까지 반영할 수 있게 미리 잡아 둔다
    final notifier = ref.read(routineFlowProvider.notifier);
    final controller = ref.read(cardPhotoControllerProvider);
    // 시트가 사라진 뒤에도 남아 있는 자리 — 맨 위 Overlay 는 Navigator 아래라
    // 여기서 팝업을 띄울 수 있다(Navigator 자신의 context 는 안 된다).
    final rootContext = Overlay.of(context, rootOverlay: true).context;

    setState(() {
      _phase = _Phase.uploading;
      _failure = null;
    });

    final result = await controller.uploadPhoto(
      routineId: widget.routineId,
      stepId: widget.stepId,
      photo: photo,
    );

    final card = result.card;
    if (card != null) {
      // 새 imagePath 가 오면 이미지 캐시 열쇠가 달라져 그림이 바뀐다
      notifier.applyStepImage(widget.stepId, card.imagePath!, isAiPicture: false);
      if (mounted) {
        setState(() {
          _phase = _Phase.idle;
          _retryPhoto = null;
        });
      }
      return;
    }

    final failure = result.failure ?? PhotoFailure.pick;
    if (mounted) {
      setState(() {
        _phase = _Phase.failed;
        _failure = failure;
        // 같은 사진으로 다시 해도 되는 실패만 사진을 들고 있는다
        _retryPhoto = failure.kind == PhotoFailureKind.retrySame ? photo : null;
      });
      return;
    }

    // 올리는 도중 시트가 닫혔다 — 인라인으로 알릴 자리가 없으니 팝업으로 알린다.
    // 실패를 삼키면 보호자는 그림이 바뀐 줄 안다.
    if (rootContext.mounted) {
      await showElumDialog<void>(
        context: rootContext,
        title: rootContext.l10n.cardPhotoUploadFailedDialog(failure.message),
        code: failure.code,
        icon: ElumDialogIcon.alert,
        actions: [
          ElumDialogAction(
            label: rootContext.l10n.commonConfirm,
            tone: ElumDialogTone.danger,
          ),
        ],
      );
    }
  }

  /// 다시 그리기: 확인 시트 > 그리는 중 > 성공이면 새 열쇠로 교체, 실패면 에러 코드 팝업 (그림 그대로)
  Future<void> _regenerate() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final isConfirmed = await CardRegenerateSheet.show(context);
      if (!isConfirmed || !mounted) return;
      await _runRegenerate();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _runRegenerate() async {
    // await 뒤 시트가 사라져도 끝까지 반영하고 알릴 수 있게 미리 잡아 둠 (사진 올리기와 같은 이유)
    final notifier = ref.read(routineFlowProvider.notifier);
    final controller = ref.read(cardPhotoControllerProvider);
    final rootContext = Overlay.of(context, rootOverlay: true).context;
    final messenger = ScaffoldMessenger.maybeOf(context);
    setState(() {
      _phase = _Phase.regenerating;
      _failure = null;
    });

    final regenerateResult = await controller.regenerateImage(routineId: widget.routineId, stepId: widget.stepId);
    if (mounted) setState(() => _phase = _Phase.idle);

    final card = regenerateResult.card;
    if (card != null) {
      // 새 imagePath 가 오면 이미지 캐시 열쇠가 달라져 그림이 바뀐다
      notifier.applyStepImage(widget.stepId, card.imagePath!, isAiPicture: true);
      if (rootContext.mounted) showElumToastOn(messenger, rootContext.l10n.cardRegenerateDoneToast);
      return;
    }
    final targetContext = mounted ? context : rootContext;
    if (!targetContext.mounted) return;
    await showFailure(
      targetContext,
      regenerateResult.failure,
      title: targetContext.l10n.cardRegenerateFailedTitle,
      fallback: targetContext.l10n.cardRegenerateFailedFallback,
      fallbackCode: CardPhotoBlock.regenerateErrorCode,
    );
  }

  void _onFailureButton() {
    final failure = _failure;
    if (failure == null || _busy) return;
    switch (failure.kind) {
      case PhotoFailureKind.retrySame:
        final photo = _retryPhoto;
        if (photo == null) {
          _start();
          return;
        }
        setState(() => _busy = true);
        _upload(photo).whenComplete(() {
          if (mounted) setState(() => _busy = false);
        });
      case PhotoFailureKind.pickAnother:
        _start();
      case PhotoFailureKind.dismissOnly:
        setState(() {
          _phase = _Phase.idle;
          _failure = null;
        });
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final space = context.space;
    final step = _step();

    return SizedBox(
      height: CardPhotoBlock.height.h,
      width: double.infinity,
      child: Stack(
        children: [
          // 카드 그림 칸과 **같은 비율**(313:230)의 미리보기를 가운데에 둔다. 시트 폭
          // 전체 띠로 두면 사진이 카드에서 어떻게 잘리는지 알 수 없다.
          // 칩은 이 미리보기 안쪽 오른쪽 아래에 붙는다.
          Positioned.fill(
            child: Center(
              child: AspectRatio(
                aspectRatio: CardPhotoBlock.previewAspect,
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: colors.surface,
                          borderRadius: BorderRadius.circular(space.xs),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(space.xs),
                          child: CardImage(
                            routineId: widget.routineId,
                            stepId: widget.stepId,
                            imagePath: step?.imagePath,
                            // 사진·AI 그림이 없으면 번들 그림(예시 이미지 > 픽토그램)이 자리를 채운다. 사진 바꾸기 칩은 그대로다.
                            pictogramId: step?.pictogramId,
                            exampleImageId: step?.exampleImageId,
                            pictogramLabel: step?.displayTitle ?? '',
                            // 픽토그램도 없으면 기본 카드의 '사진 추가' 자리를 그대로 두고, 눌러도 같은 사진 흐름이
                            // 시작되게 잇는다. 올리는 중에는 누를 수 없다.
                            emptyBuilder: (_) => DefaultCardPhotoSlot(
                              onAddPhoto: _phase == _Phase.idle && !_busy
                                  ? _start
                                  : null,
                            ),
                          ),
                        ),
                      ),
                    ),
                    if (_phase == _Phase.idle && (step?.isAiPicture ?? false))
                      Positioned(
                        left: 4.w,
                        bottom: 0,
                        child: _Chip(
                          asset: AppAssets.iconRefresh,
                          label: context.l10n.cardRegenerateChip,
                          onTap: _busy ? null : _regenerate,
                        ),
                      ),
                    if (_phase == _Phase.idle)
                      Positioned(
                        right: 4.w,
                        bottom: 0,
                        child: _Chip(
                          key: CardPhotoBlock.chipTapKey,
                          asset: AppAssets.iconCamera,
                          label: context.l10n.cardPhotoChange,
                          onTap: _busy ? null : _start,
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
          if (_phase == _Phase.uploading) _ProgressOverlay(message: context.l10n.cardPhotoUploading),
          if (_phase == _Phase.regenerating) _ProgressOverlay(message: context.l10n.cardRegenerateInProgress),
          if (_phase == _Phase.failed && _failure != null)
            _FailureOverlay(failure: _failure!, onButton: _onFailureButton),
        ],
      ),
    );
  }
}
