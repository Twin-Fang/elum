import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../core/l10n/l10n_context.dart';
import '../../../../core/theme/app_motion.dart';
import '../../../../core/theme/theme_context_ext.dart';
import '../../../../core/widgets/app_pressable.dart';
import '../../../../core/widgets/kept_text.dart';
import '../../../../core/widgets/pro_badge.dart';
import '../../domain/card_export_options.dart';

/// 카드 저장 모양 고르기: 그림 타일 3개 한 줄 (카드 한 장씩 · 일과 한 장 · 오려 쓰는 카드, #1461)
///
/// 고른 타일은 남색 테두리. 잠긴 모양은 아래 가장자리에 PRO 배지 ([ProBadgeHang], 누르면 부르는 쪽이 Pro 미리 보기)
class CardExportFormatTiles extends StatelessWidget {
  const CardExportFormatTiles({
    super.key,
    required this.selected,
    required this.isLocked,
    required this.onSelected,
  });

  final CardExportFormat selected;

  /// 이 모양이 Free 에게 잠겼는가 (PRO 배지)
  final bool Function(CardExportFormat format) isLocked;
  final ValueChanged<CardExportFormat> onSelected;

  /// 화면에 놓는 차례 (Free 가 쓰는 카드 한 장씩 먼저)
  static const _order = [CardExportFormat.cardImages, CardExportFormat.routineSheet, CardExportFormat.cutCards];
  static const _tileGap = 8.0;

  @override
  Widget build(BuildContext context) {
    final hasLockedFormat = _order.any(isLocked);
    final tiles = IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final (index, format) in _order.indexed) ...[
            if (index > 0) SizedBox(width: _tileGap.w),
            Expanded(
              child: _FormatTile(
                format: format,
                isSelected: format == selected,
                isLocked: isLocked(format),
                onTap: () => onSelected(format),
              ),
            ),
          ],
        ],
      ),
    );
    // 잠긴 타일의 PRO 배지가 아래로 튀어나오는 만큼 비움 (아래 묶음을 덮지 않게)
    if (!hasLockedFormat) return tiles;
    return Padding(padding: EdgeInsets.only(bottom: ProBadgeHang.defaultHang.w), child: tiles);
  }

  /// 모양 > 이름
  static String labelOf(BuildContext context, CardExportFormat format) {
    final l10n = context.l10n;
    return switch (format) {
      CardExportFormat.routineSheet => l10n.cardExportFormatRoutineSheet,
      CardExportFormat.cutCards => l10n.cardExportFormatCutCards,
      CardExportFormat.cardImages => l10n.cardExportFormatCardImages,
    };
  }

  /// 모양 > 한 줄 설명
  static String captionOf(BuildContext context, CardExportFormat format) {
    final l10n = context.l10n;
    return switch (format) {
      CardExportFormat.routineSheet => l10n.cardExportFormatRoutineSheetCaption,
      CardExportFormat.cutCards => l10n.cardExportFormatCutCardsCaption,
      CardExportFormat.cardImages => l10n.cardExportFormatCardImagesCaption,
    };
  }
}

/// 타일 한 개: 작은 그림 > 이름 > 한 줄 설명
class _FormatTile extends StatelessWidget {
  const _FormatTile({
    required this.format,
    required this.isSelected,
    required this.isLocked,
    required this.onTap,
  });

  final CardExportFormat format;
  final bool isSelected;
  final bool isLocked;
  final VoidCallback onTap;

  static const _radius = 16.0;
  static const _paddingH = 6.0;
  static const _paddingV = 12.0;
  static const _pictureHeight = 52.0;
  static const _pictureToLabel = 8.0;
  static const _labelToCaption = 2.0;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final borderWidth = context.space.selectedBorderWidth;
    final tile = AnimatedContainer(
      duration: AppMotion.fast,
      curve: AppMotion.standard,
      padding: EdgeInsets.symmetric(horizontal: _paddingH.w, vertical: _paddingV.h),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(_radius.r),
        // 안 고른 타일도 같은 두께 투명 테두리 (고를 때 글자가 밀리지 않게)
        border: Border.all(color: isSelected ? colors.textPrimary : colors.surface, width: borderWidth),
      ),
      child: Column(
        children: [
          SizedBox(height: _pictureHeight.h, child: Center(child: _FormatPicture(format: format))),
          SizedBox(height: _pictureToLabel.h),
          // 좁은 타일이라 어절 단위로만 줄바꿈 (`순서대 / 로` 방지)
          KeptText(
            CardExportFormatTiles.labelOf(context, format),
            textAlign: TextAlign.center,
            style: context.typo.settingsTileLabel.copyWith(color: colors.textPrimary),
          ),
          SizedBox(height: _labelToCaption.h),
          KeptText(
            CardExportFormatTiles.captionOf(context, format),
            textAlign: TextAlign.center,
            style: context.typo.caption.copyWith(color: colors.textSecondary),
          ),
        ],
      ),
    );
    return Semantics(
      button: true,
      selected: isSelected,
      child: AppPressable(
        onTap: onTap,
        child: ProBadgeHang(isShown: isLocked, child: tile),
      ),
    );
  }
}

/// 타일 작은 그림: 카드 두 장 겹침 · A4 에 카드 6칸 · A4 에 자를 선 4칸
class _FormatPicture extends StatelessWidget {
  const _FormatPicture({required this.format});

  final CardExportFormat format;

  static const _paperWidth = 34.0;
  static const _paperHeight = 48.0;
  static const _paperPadding = 4.0;
  static const _cellGap = 2.0;
  static const _cardWidth = 24.0;
  static const _cardHeight = 30.0;
  static const _cardRadius = 4.0;
  static const _cardTiltRadians = -0.18;

  /// 카드 두 장 겹친 그림 상자 (뒤 카드가 기울어 삐져나오는 폭 · 높이 포함)
  static const _stackWidth = 40.0;
  static const _stackHeight = 36.0;

  /// 기울인 뒤 카드가 내려앉는 깊이
  static const _tiltedCardTop = 4.0;

  /// 칸 가로:세로 (일과 한 장은 정사각, 오려 쓰는 카드는 카드 비율에 가깝게)
  static const _routineCellAspectRatio = 1.0;
  static const _cutCellAspectRatio = 0.75;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final stepColors = [colors.stepBadge1, colors.stepBadge2, colors.stepBadge3, colors.stepBadge4];
    return switch (format) {
      CardExportFormat.cardImages => SizedBox(
        width: _stackWidth.w,
        height: _stackHeight.w,
        child: Stack(
          children: [
            Positioned(left: 0, top: _tiltedCardTop.w, child: Transform.rotate(angle: _cardTiltRadians, child: _miniCard(context, stepColors[0]))),
            Positioned(right: 0, top: 0, child: _miniCard(context, stepColors[1])),
          ],
        ),
      ),
      CardExportFormat.routineSheet => _paper(context, cellCount: 6, cellColor: (index) => stepColors[index % stepColors.length]),
      CardExportFormat.cutCards => _paper(context, cellCount: 4, cellColor: (_) => stepColors[2], isCut: true),
    };
  }

  Widget _miniCard(BuildContext context, Color color) => Container(
    width: _cardWidth.w,
    height: _cardHeight.w,
    decoration: BoxDecoration(
      color: color,
      borderRadius: BorderRadius.circular(_cardRadius.r),
      border: Border.all(color: context.colors.surface, width: context.space.borderWidth * 2),
    ),
  );

  // A4 한 장: 흰 종이 > 2열 칸 (오려 쓰는 카드는 칸마다 자를 선)
  Widget _paper(BuildContext context, {required int cellCount, required Color Function(int index) cellColor, bool isCut = false}) {
    final colors = context.colors;
    return Container(
      width: _paperWidth.w,
      height: _paperHeight.w,
      padding: EdgeInsets.all(_paperPadding.w),
      decoration: BoxDecoration(
        color: colors.surface,
        border: Border.all(color: colors.textPlaceholder, width: context.space.borderWidth),
        borderRadius: BorderRadius.circular(_cardRadius.r / 2),
      ),
      child: GridView.count(
        crossAxisCount: 2,
        mainAxisSpacing: _cellGap.w,
        crossAxisSpacing: _cellGap.w,
        padding: EdgeInsets.zero,
        physics: const NeverScrollableScrollPhysics(),
        childAspectRatio: isCut ? _cutCellAspectRatio : _routineCellAspectRatio,
        children: [
          for (var index = 0; index < cellCount; index++)
            DecoratedBox(
              decoration: BoxDecoration(
                color: cellColor(index),
                border: isCut ? Border.all(color: colors.textPlaceholder, width: context.space.borderWidth) : null,
              ),
            ),
        ],
      ),
    );
  }
}
