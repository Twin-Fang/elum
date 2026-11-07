import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../../core/assets/app_assets.dart';
import '../../../../core/l10n/l10n_context.dart';
import '../../../../core/theme/theme_context_ext.dart';
import '../../../../core/widgets/app_pressable.dart';
import '../../../../core/widgets/elum_dialog.dart';
import '../../../../shared/models/action_card.dart';
import '../../../../shared/models/image_style.dart';
import '../../../member/application/member_providers.dart';
import '../../../member/application/plan_access.dart';
import '../../../subscription/application/plan_paywall_entry.dart';
import '../../../subscription/domain/plan_benefit.dart';
import '../../application/routine_notifier.dart';
import '../../application/card_photo_controller.dart';
import '../../data/card_photo.dart';
import '../../data/card_photo_picker.dart';
import 'card_image.dart';
import 'card_photo_permission_screen.dart';
import 'card_photo_source_sheet.dart';
import 'card_redraw_flow.dart';
import 'default_card_art.dart';
import '../../../../core/widgets/elum_spinner.dart';

part 'card_photo_block_parts.dart';

/// 카드 수정 시트 안의 그림 칸 — 그림 아래 `사진 바꾸기` · `다시 그리기`(또는 `AI 그림 그리기`) 칩과 그 뒤의 모든 상태.
///
/// **임시 시안이다.** 디자이너 확정 전 제시용 목업(`opt2_A`)을 그대로 옮겼다.
///
/// 흐름: 칩 → 고르기 시트 → (카메라·갤러리) → 올리는 중 → 성공(그림 갈아 끼움) / 실패.
/// 취소는 아무 일도 없고, 권한 거부는 우회 안내, 올리는 중은 칩을 감춰 두 번 못 누르며,
/// 실패는 문구 + **에러 코드** + `다시 하기`다.
///
/// 다시 그리기 · AI 그림 그리기: 칩 → 요청 시트 → 그리는 중 → 나란히 고르기 → 바꾸기(토스트) / 실패(에러 코드 팝업, 그림 그대로).
/// AI 맞춤 그림이 없는 요금제는 그 칩 자리에 Pro 안내 칩.
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

  /// 그리는 중 덮개 문구: 처음 그리기면 `그리고 있어요`, 아니면 `다시 그리고 있어요`
  var _isDrawingFirstPicture = false;

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

  /// 다시 그리기 · AI 그림 그리기: 요청 시트 > 그리는 중 > 나란히 고르기 > 바꾸기 (실패는 에러 코드 팝업, 그림 그대로)
  Future<void> _redraw(ActionCard step) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await runCardRedrawFlow(
        context: context,
        ref: ref,
        routineId: widget.routineId,
        step: step,
        onDrawingChanged: (isDrawing) {
          if (!mounted) return;
          setState(() {
            _phase = isDrawing ? _Phase.regenerating : _Phase.idle;
            _failure = null;
            _isDrawingFirstPicture = !step.isAiPicture;
          });
        },
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
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

  /// 그림 칩 하나: AI 그림 카드는 `다시 그리기`, 그림 없는 카드는 `AI 그림 그리기` (사진·가져온 그림·사진만 쓰기·설명 없음은 없음)
  /// AI 맞춤 그림이 없는 요금제면 같은 자리에 Pro 안내 칩 (살 수 없는 동안은 숨김)
  Widget? _drawChip(BuildContext context, ActionCard? step) {
    if (step == null) return null;
    final l10n = context.l10n;
    final planAccess = ref.watch(planAccessProvider);
    final imageStyle = ref.watch(memberProvider).value?.imageStyle ?? ImageStyle.character;
    final imagePath = step.imagePath;
    final canDrawFirstPicture = (imagePath == null || imagePath.isEmpty) &&
        step.description.trim().isNotEmpty &&
        imageStyle.drawsCardImages;
    if (!step.isAiPicture && !canDrawFirstPicture) return null;

    if (!planAccess.canUseAiPictures) {
      if (!planAccess.shouldPromoteBenefit(PlanBenefit.aiImageStyles)) return null;
      return _Chip(
        asset: AppAssets.iconRefresh,
        label: step.isAiPicture ? l10n.cardRedrawProChip : l10n.cardFirstDrawProChip,
        onTap: _busy ? null : () => openProOnlyNotice(context, ref),
      );
    }
    return _Chip(
      asset: AppAssets.iconRefresh,
      label: step.isAiPicture ? l10n.cardRegenerateChip : l10n.cardFirstDrawChip,
      onTap: _busy ? null : () => _redraw(step),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final space = context.space;
    final step = _step();

    // 그림 아래 칩 줄 — 그림 폭(204)에 칩 두 개가 안 들어가 글자가 잘려서 그림 밖으로 뺌.
    // 좁거나 글자가 크면 다음 줄로 내림. 올리는 중·실패에도 자리는 남겨 시트 높이가 튀지 않음
    final chips = Visibility(
      visible: _phase == _Phase.idle,
      maintainSize: true,
      maintainAnimation: true,
      maintainState: true,
      child: Wrap(
        alignment: WrapAlignment.center,
        spacing: space.xs,
        children: [
          ?_drawChip(context, step),
          _Chip(
            key: CardPhotoBlock.chipTapKey,
            asset: AppAssets.iconCamera,
            label: context.l10n.cardPhotoChange,
            onTap: _busy ? null : _start,
          ),
        ],
      ),
    );

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
      height: CardPhotoBlock.height.h,
      width: double.infinity,
      child: Stack(
        children: [
          // 카드 그림 칸과 **같은 비율**(313:230)의 미리보기를 가운데에 둔다. 시트 폭
          // 전체 띠로 두면 사진이 카드에서 어떻게 잘리는지 알 수 없다.
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
                  ],
                ),
              ),
            ),
          ),
          if (_phase == _Phase.uploading) _ProgressOverlay(message: context.l10n.cardPhotoUploading),
          if (_phase == _Phase.regenerating)
            _ProgressOverlay(
              message: _isDrawingFirstPicture
                  ? context.l10n.cardFirstDrawInProgress
                  : context.l10n.cardRegenerateInProgress,
            ),
          if (_phase == _Phase.failed && _failure != null)
            _FailureOverlay(failure: _failure!, onButton: _onFailureButton),
        ],
      ),
        ),
        chips,
      ],
    );
  }
}
