part of 'card_photo_block.dart';

// 카드 그림 칸 부품: 칩 · 진행 덮개 · 실패 덮개

/// 칩 모양: 알약 (시안 모서리 100)
const _chipPillRadius = 100.0;

/// 칩 앞 아이콘 (`fi-br` 16, 남색)
class _ChipIcon extends StatelessWidget {
  const _ChipIcon({required this.asset});

  final String asset;

  static const _size = 16.0;

  @override
  Widget build(BuildContext context) {
    return SvgPicture.asset(
      asset,
      width: _size.w,
      height: _size.w,
      excludeFromSemantics: true,
      colorFilter: ColorFilter.mode(
        context.colors.textPrimary,
        BlendMode.srcIn,
      ),
    );
  }
}

/// 그림 아래 칩 (`사진 바꾸기` · `다시 그리기`) — 보이는 알약은 작아도 누름 영역은 48 이상이다.
/// Free 권유 칩은 글자 뒤 Pro 배지, 낭독은 [semanticLabel] (`Pro로 다시 그리기`)
class _Chip extends StatelessWidget {
  const _Chip({
    super.key,
    required this.asset,
    required this.label,
    required this.onTap,
    this.shouldShowProBadge = false,
    this.semanticLabel,
  });

  final String asset;
  final String label;
  final VoidCallback? onTap;
  final bool shouldShowProBadge;

  /// null 이면 [label] 을 읽음
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return AppPressable(
      onTap: onTap,
      semanticLabel: semanticLabel ?? label,
      child: ConstrainedBox(
        constraints: BoxConstraints(minHeight: 48.h < 48 ? 48 : 48.h),
        child: Align(
          widthFactor: 1,
          child: Container(
            padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
            decoration: BoxDecoration(
              color: colors.editChipBg,
              borderRadius: BorderRadius.circular(_chipPillRadius),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _ChipIcon(asset: asset),
                SizedBox(width: 6.w),
                LabelWithProBadge(
                  label: Text(
                    label,
                    style: context.typo.editChipLabel.copyWith(
                      color: colors.textPrimary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  shouldShowProBadge: shouldShowProBadge,
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

/// 진행 중 덮개 (올리는 중 · 다시 그리는 중)
class _ProgressOverlay extends StatelessWidget {
  const _ProgressOverlay({required this.message});

  final String message;

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
            ElumSpinner(size: 36.w, strokeWidth: 3, color: colors.textPrimary),
            SizedBox(height: 12.h),
            Text(
              message,
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
                    borderRadius: BorderRadius.circular(_chipPillRadius),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (!dismiss) ...[
                        const _ChipIcon(asset: AppAssets.iconRefresh),
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
