import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../core/l10n/l10n_context.dart';
import '../../../../core/theme/theme_context_ext.dart';
import '../../../../core/widgets/app_pressable.dart';
import '../../../../core/widgets/elum_dialog.dart';
import '../../../../shared/models/action_card.dart';
import '../../application/routine_notifier.dart';
import '../../application/card_photo_controller.dart';
import '../../data/card_photo.dart';
import '../../data/card_photo_picker.dart';
import 'card_image.dart';
import 'card_photo_permission_screen.dart';
import 'card_photo_source_sheet.dart';
import 'default_card_art.dart';

/// 카드 수정 시트 안의 그림 칸 — 그림 위 `사진 바꾸기` 칩과 그 뒤의 모든 상태.
///
/// **임시 시안이다.** 디자이너 확정 전 제시용 목업(`opt2_A`)을 그대로 옮겼다.
///
/// 흐름: 칩 → 고르기 시트 → (카메라·갤러리) → 올리는 중 → 성공(그림 갈아 끼움) / 실패.
/// 취소는 아무 일도 없고, 권한 거부는 우회 안내, 올리는 중은 칩을 감춰 두 번 못 누르며,
/// 실패는 문구 + **에러 코드** + `다시 하기`다.
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

enum _Phase { idle, uploading, failed }

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
      notifier.applyStepImage(widget.stepId, card.imagePath!);
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
                            // 사진·AI 그림이 없으면 무료 픽토그램이 자리를 채운다. 사진 바꾸기 칩은 그대로다.
                            pictogramId: step?.pictogramId,
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
                    if (_phase == _Phase.idle)
                      Positioned(
                        right: 4.w,
                        bottom: 0,
                        child: _Chip(onTap: _busy ? null : _start),
                      ),
                  ],
                ),
              ),
            ),
          ),
          if (_phase == _Phase.uploading) const _UploadingOverlay(),
          if (_phase == _Phase.failed && _failure != null)
            _FailureOverlay(failure: _failure!, onButton: _onFailureButton),
        ],
      ),
    );
  }
}

/// `사진 바꾸기` 칩 — 보이는 알약은 작아도 누름 영역은 48 이상이다.
class _Chip extends StatelessWidget {
  const _Chip({required this.onTap});

  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return AppPressable(
      onTap: onTap,
      semanticLabel: context.l10n.cardPhotoChange,
      child: SizedBox(
        key: CardPhotoBlock.chipTapKey,
        height: 48.h < 48 ? 48 : 48.h,
        child: Align(
          child: Container(
            padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
            decoration: BoxDecoration(
              color: colors.editChipBg,
              borderRadius: BorderRadius.circular(18.r),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.photo_camera_outlined,
                  size: 16.w,
                  color: colors.textPrimary,
                ),
                SizedBox(width: 6.w),
                Text(
                  context.l10n.cardPhotoChange,
                  style: context.typo.editChipLabel.copyWith(
                    color: colors.textPrimary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// 그림 위를 덮는 반투명 판 — 뒤 그림은 흐릿하게 비친다(목업 `upload_loading`).
class _Overlay extends StatelessWidget {
  const _Overlay({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final space = context.space;

    return Positioned.fill(
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: context.colors.surface.withValues(alpha: 0.92),
          borderRadius: BorderRadius.circular(space.xs),
        ),
        child: Padding(
          padding: EdgeInsets.all(12.w),
          // 글자를 키워도 판 밖으로 넘치지 않게 줄인다
          child: FittedBox(fit: BoxFit.scaleDown, child: child),
        ),
      ),
    );
  }
}

class _UploadingOverlay extends StatelessWidget {
  const _UploadingOverlay();

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return _Overlay(
      child: Semantics(
        // 낭독기가 진행 상황을 바로 읽는다
        liveRegion: true,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 36.w,
              height: 36.w,
              child: CircularProgressIndicator(
                strokeWidth: 3,
                color: colors.textPrimary,
              ),
            ),
            SizedBox(height: 12.h),
            Text(
              context.l10n.cardPhotoUploading,
              style: context.typo.body.copyWith(color: colors.textPrimary),
            ),
          ],
        ),
      ),
    );
  }
}

class _FailureOverlay extends StatelessWidget {
  const _FailureOverlay({required this.failure, required this.onButton});

  final PhotoFailure failure;
  final VoidCallback onButton;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typo = context.typo;
    final dismiss = failure.kind == PhotoFailureKind.dismissOnly;

    return _Overlay(
      child: Semantics(
        liveRegion: true,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              context.l10n.cardPhotoUploadFailed,
              style: typo.body.copyWith(
                color: colors.textPrimary,
                fontWeight: FontWeight.w700,
              ),
            ),
            SizedBox(height: 4.h),
            Text(
              failure.message,
              textAlign: TextAlign.center,
              style: typo.bodySmall.copyWith(color: colors.textSecondary),
            ),
            SizedBox(height: 2.h),
            // 제보를 받았을 때 어디서 터졌는지 찾는 식별자
            Text(
              failure.code,
              style: typo.bodySmall.copyWith(color: colors.textSecondary),
            ),
            SizedBox(height: 8.h),
            AppPressable(
              onTap: onButton,
              semanticLabel: dismiss
                  ? context.l10n.commonConfirm
                  : context.l10n.cardPhotoRetry,
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 48, minWidth: 48),
                child: Container(
                  alignment: Alignment.center,
                  padding: EdgeInsets.symmetric(
                    horizontal: 16.w,
                    vertical: 8.h,
                  ),
                  decoration: BoxDecoration(
                    color: colors.editChipBg,
                    borderRadius: BorderRadius.circular(18.r),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (!dismiss) ...[
                        Icon(
                          Icons.refresh,
                          size: 16.w,
                          color: colors.textPrimary,
                        ),
                        SizedBox(width: 6.w),
                      ],
                      Text(
                        dismiss
                            ? context.l10n.commonConfirm
                            : context.l10n.cardPhotoRetry,
                        style: typo.editChipLabel.copyWith(
                          color: colors.textPrimary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
