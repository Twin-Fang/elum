import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../core/l10n/l10n_context.dart';
import '../../../../core/theme/theme_context_ext.dart';
import '../../../../core/widgets/elum_choice_chip.dart';
import '../../../../core/widgets/pro_upsell_button.dart';
import '../../../../core/widgets/settings_group.dart';
import '../../../../core/widgets/settings_switch_tile.dart';
import '../../../../core/widgets/settings_tile.dart';
import '../../domain/card_export_options.dart';
import 'card_export_format_tiles.dart';

/// Free 가 잠긴 값을 고름 > 그 값으로 바꾼 설정 (Pro 미리 보기로만 그림, 저장 설정은 그대로)
typedef CardExportLockedPick = void Function(CardExportOptions previewOptions, CardExportLock lock);

/// 잠긴 값의 종류: 모양·배치(`cardExportAllLayouts`) · 디자인(`cardExportAllThemes`)
enum CardExportLock { layout, theme }

/// 카드 저장 설정: 모양 타일 > 꾸미기(디자인 칩 · 카드 문장 · A4 면 용지 방향 · 오려 쓰는 카드면 장수 · 카드 크기) > (Free) Pro 안내 (#1461)
///
/// 누르면 바로 바뀜 (고르기 시트 없음). Free 는 카드 한 장씩 · 기본 디자인만, 나머지는 PRO 배지와 함께 보이고 고르면 Pro 미리 보기
class CardExportOptionsPanel extends StatelessWidget {
  const CardExportOptionsPanel({
    super.key,
    required this.options,
    required this.onChanged,
    required this.canUseAllLayouts,
    required this.canUseAllThemes,
    required this.shouldShowProLayouts,
    required this.shouldShowProThemes,
    required this.onLockedPick,
    this.onUpsellTap,
  });

  final CardExportOptions options;
  final ValueChanged<CardExportOptions> onChanged;

  /// 모양·배치를 모두 고를 수 있는가 (`cardExportAllLayouts`)
  final bool canUseAllLayouts;

  /// 디자인을 모두 고를 수 있는가 (`cardExportAllThemes`)
  final bool canUseAllThemes;

  /// 잠긴 모양을 PRO 배지와 함께 보이는가 (살 수 없으면 숨김)
  final bool shouldShowProLayouts;

  /// 잠긴 디자인을 PRO 배지와 함께 보이는가 (살 수 없으면 숨김)
  final bool shouldShowProThemes;

  final CardExportLockedPick onLockedPick;

  /// 아래 Pro 안내의 버튼 (null 이면 안내를 그리지 않음)
  final VoidCallback? onUpsellTap;

  static const _groupGap = 20.0;
  static const _headerToContent = 8.0;
  static const _headerInsetH = 4.0;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colors = context.colors;
    final upsellTap = onUpsellTap;
    final themeChoices = [
      for (final theme in CardDesignTheme.values)
        if (!_isThemeLocked(theme) || shouldShowProThemes) theme,
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // 모양 고르기 (살 수 없는 Free 는 잠긴 모양을 숨겨 카드 한 장씩만 남음 > 줄째 생략)
        if (canUseAllLayouts || shouldShowProLayouts) ...[
          Padding(
            padding: EdgeInsets.symmetric(horizontal: _headerInsetH.w),
            child: Text(
              l10n.cardExportFormatSection,
              style: context.typo.settingsGroupLabel.copyWith(color: colors.settingsGroupLabel),
            ),
          ),
          SizedBox(height: _headerToContent.h),
          CardExportFormatTiles(selected: options.format, isLocked: _isFormatLocked, onSelected: _onFormatSelected),
          SizedBox(height: _groupGap.h),
        ],
        SettingsGroup(
          header: l10n.cardExportStyleSection,
          children: [
            // 디자인: 고를 값이 둘 이상일 때만 (살 수 없는 Free 는 기본 하나라 줄째 생략)
            if (themeChoices.length > 1)
              _ChipRow<CardDesignTheme>(
                label: l10n.cardExportThemeSection,
                values: themeChoices,
                selected: options.theme,
                labelOf: (theme) => themeLabelOf(context, theme),
                isLocked: _isThemeLocked,
                onSelected: _onThemeSelected,
              ),
            SettingsSwitchTile(
              label: l10n.cardExportIncludeText,
              value: options.shouldIncludeText,
              onChanged: (value) => onChanged(options.copyWith(shouldIncludeText: value)),
            ),
            // 배치: 종이 모양일 때만 (카드 한 장씩은 카드 크기 그대로)
            if (options.format.hasPaperLayout)
              _ChipRow<PaperOrientation>(
                label: l10n.cardExportOrientationRow,
                values: PaperOrientation.values,
                selected: options.orientation,
                labelOf: (orientation) => _orientationLabel(context, orientation),
                onSelected: (orientation) => onChanged(options.copyWith(orientation: orientation)),
              ),
            if (options.format == CardExportFormat.cutCards) ...[
              _ChipRow<CardsPerPage>(
                label: l10n.cardExportPerPageRow,
                values: CardsPerPage.values,
                selected: options.cardsPerPage,
                labelOf: (perPage) => l10n.cardExportPerPage(perPage.count),
                onSelected: (perPage) => onChanged(options.copyWith(cardsPerPage: perPage)),
              ),
              _ChipRow<CardSize>(
                label: l10n.cardExportCardSizeRow,
                values: CardSize.values,
                selected: options.cardSize,
                labelOf: (size) => _cardSizeLabel(context, size),
                onSelected: (size) => onChanged(options.copyWith(cardSize: size)),
              ),
            ],
          ],
        ),
        if (upsellTap != null) ...[
          SizedBox(height: _groupGap.h),
          _UpsellCard(onTap: upsellTap),
        ],
      ],
    );
  }

  // 모양 고름: 잠긴 모양이면 Pro 미리 보기, 아니면 설정 변경
  void _onFormatSelected(CardExportFormat format) {
    if (format == options.format) return;
    final next = options.copyWith(format: format);
    _isFormatLocked(format) ? onLockedPick(next, CardExportLock.layout) : onChanged(next);
  }

  void _onThemeSelected(CardDesignTheme theme) {
    if (theme == options.theme) return;
    final next = options.copyWith(theme: theme);
    _isThemeLocked(theme) ? onLockedPick(next, CardExportLock.theme) : onChanged(next);
  }

  bool _isFormatLocked(CardExportFormat format) => !canUseAllLayouts && format != CardExportFormat.cardImages;

  bool _isThemeLocked(CardDesignTheme theme) => theme.isProOnly && !canUseAllThemes;

  /// 디자인 > 이름
  static String themeLabelOf(BuildContext context, CardDesignTheme theme) {
    final l10n = context.l10n;
    return switch (theme) {
      CardDesignTheme.basic => l10n.cardExportThemeBasic,
      CardDesignTheme.simple => l10n.cardExportThemeSimple,
      CardDesignTheme.inkSaver => l10n.cardExportThemeInkSaver,
      CardDesignTheme.monochrome => l10n.cardExportThemeMonochrome,
      CardDesignTheme.largeText => l10n.cardExportThemeLargeText,
    };
  }

  static String _orientationLabel(BuildContext context, PaperOrientation orientation) => switch (orientation) {
    PaperOrientation.portrait => context.l10n.cardExportOrientationPortrait,
    PaperOrientation.landscape => context.l10n.cardExportOrientationLandscape,
  };

  static String _cardSizeLabel(BuildContext context, CardSize size) => switch (size) {
    CardSize.fit => context.l10n.cardExportCardSizeFit,
    CardSize.medium => context.l10n.cardExportCardSizeMedium,
    CardSize.small => context.l10n.cardExportCardSizeSmall,
  };
}

/// 묶음 안 한 줄: 이름 > 칩 줄 (넘치면 옆으로 밀기). 잠긴 값은 PRO 배지
class _ChipRow<T> extends StatelessWidget {
  const _ChipRow({
    required this.label,
    required this.values,
    required this.selected,
    required this.labelOf,
    required this.onSelected,
    this.isLocked,
  });

  final String label;
  final List<T> values;
  final T selected;
  final String Function(T value) labelOf;
  final ValueChanged<T> onSelected;

  /// 이 값이 잠겼는가 (null 이면 잠긴 값 없음)
  final bool Function(T value)? isLocked;

  /// 칩 줄 좌우: 같은 묶음의 켜고 끄기 줄 글자와 왼쪽을 맞춤
  static const _paddingH = SettingsTile.cardPadLeft;
  static const _paddingV = 14.0;
  static const _labelToChips = 10.0;
  static const _chipGap = 6.0;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Padding(
      padding: EdgeInsets.symmetric(vertical: _paddingV.h),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.symmetric(horizontal: _paddingH.w),
            child: Text(label, style: context.typo.settingsTileLabel.copyWith(color: colors.textPrimary)),
          ),
          SizedBox(height: _labelToChips.h),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: EdgeInsets.symmetric(horizontal: _paddingH.w),
            child: Row(
              children: [
                for (final (index, value) in values.indexed) ...[
                  if (index > 0) SizedBox(width: _chipGap.w),
                  ElumChoiceChip(
                    label: labelOf(value),
                    isSelected: value == selected,
                    shouldShowProBadge: isLocked?.call(value) ?? false,
                    onTap: () => onSelected(value),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Free 아래 Pro 안내 판: 제목 > 한 줄 > 민트 버튼 (요금제 화면)
class _UpsellCard extends StatelessWidget {
  const _UpsellCard({required this.onTap});

  final VoidCallback onTap;

  static const _padding = 16.0;
  static const _radius = 16.0;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colors = context.colors;
    return Container(
      padding: EdgeInsets.all(_padding.w),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(_radius.r),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l10n.cardExportUpsellTitle, style: context.typo.settingsTileLabel.copyWith(color: colors.textPrimary)),
          SizedBox(height: 4.h),
          Text(l10n.cardExportUpsellBody, style: context.typo.caption.copyWith(color: colors.textSecondary)),
          SizedBox(height: 12.h),
          ProUpsellButton(style: ProUpsellStyle.filled, onTap: onTap),
        ],
      ),
    );
  }
}
