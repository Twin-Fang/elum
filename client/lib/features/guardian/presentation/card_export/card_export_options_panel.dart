import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../core/l10n/l10n_context.dart';
import '../../../../core/theme/theme_context_ext.dart';
import '../../../../core/widgets/app_pressable.dart';
import '../../../../core/widgets/elum_check_circle.dart';
import '../../../../core/widgets/pro_badge.dart';
import '../../../../core/widgets/settings_group.dart';
import '../../../../core/widgets/settings_switch_tile.dart';
import '../../domain/card_export_options.dart';

/// 내보내기 설정: 형태 > (오려 쓰는 카드) 장수 > 카드 문장 > 디자인
class CardExportOptionsPanel extends StatelessWidget {
  const CardExportOptionsPanel({
    super.key,
    required this.options,
    required this.onChanged,
    required this.canUseAllThemes,
    required this.shouldShowProThemes,
    required this.onLockedThemeTap,
    this.teaserTheme,
  });

  final CardExportOptions options;
  final ValueChanged<CardExportOptions> onChanged;

  /// Pro 테마를 고를 수 있는가
  final bool canUseAllThemes;

  /// Pro 테마를 목록에 보이는가 (결제 전 Free 는 숨김)
  final bool shouldShowProThemes;

  /// 고를 수 없는 Pro 테마 칩 누름 (요금제 · 흐린 미리 보기 · 안내)
  final ValueChanged<CardDesignTheme> onLockedThemeTap;

  /// 흐린 미리 보기로 보고 있는 Pro 테마 (칩에 고름 표시만, 내보내기 설정은 그대로)
  final CardDesignTheme? teaserTheme;

  static const _groupGap = 20.0;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final themes = [
      for (final theme in CardDesignTheme.values)
        if (!theme.isProOnly || shouldShowProThemes) theme,
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SettingsGroup(
          header: l10n.cardExportFormatSection,
          children: [
            for (final format in CardExportFormat.values)
              _FormatRow(
                format: format,
                isSelected: options.format == format,
                onTap: () => onChanged(options.copyWith(format: format)),
              ),
          ],
        ),
        if (options.format == CardExportFormat.cutCards) ...[
          SizedBox(height: _groupGap.h),
          _ChipGroup(
            header: l10n.cardExportPerPageSection,
            chips: [
              for (final perPage in CutCardsPerPage.values)
                _OptionChip(
                  label: l10n.cardExportPerPage(perPage.count),
                  isSelected: options.cutCardsPerPage == perPage,
                  onTap: () => onChanged(options.copyWith(cutCardsPerPage: perPage)),
                ),
            ],
          ),
        ],
        SizedBox(height: _groupGap.h),
        SettingsGroup(
          children: [
            SettingsSwitchTile(
              label: l10n.cardExportIncludeText,
              value: options.shouldIncludeText,
              onChanged: (value) => onChanged(options.copyWith(shouldIncludeText: value)),
            ),
          ],
        ),
        if (themes.length > 1) ...[
          SizedBox(height: _groupGap.h),
          _ChipGroup(
            header: l10n.cardExportThemeSection,
            chips: [
              for (final theme in themes)
                _OptionChip(
                  label: _themeLabel(context, theme),
                  isSelected: (teaserTheme ?? options.theme) == theme,
                  isPro: theme.isProOnly,
                  onTap: theme.isProOnly && !canUseAllThemes
                      ? () => onLockedThemeTap(theme)
                      : () => onChanged(options.copyWith(theme: theme)),
                ),
            ],
          ),
        ],
      ],
    );
  }

  static String _themeLabel(BuildContext context, CardDesignTheme theme) {
    final l10n = context.l10n;
    return switch (theme) {
      CardDesignTheme.basic => l10n.cardExportThemeBasic,
      CardDesignTheme.simple => l10n.cardExportThemeSimple,
      CardDesignTheme.inkSaver => l10n.cardExportThemeInkSaver,
      CardDesignTheme.monochrome => l10n.cardExportThemeMonochrome,
      CardDesignTheme.largeText => l10n.cardExportThemeLargeText,
    };
  }
}

/// 형태 한 줄: 이름 + 설명 + 고른 표시
class _FormatRow extends StatelessWidget {
  const _FormatRow({required this.format, required this.isSelected, required this.onTap});

  final CardExportFormat format;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colors = context.colors;
    final (title, caption) = switch (format) {
      CardExportFormat.routineSheet => (
        l10n.cardExportFormatRoutineSheet,
        l10n.cardExportFormatRoutineSheetCaption,
      ),
      CardExportFormat.cutCards => (
        l10n.cardExportFormatCutCards,
        l10n.cardExportFormatCutCardsCaption,
      ),
      CardExportFormat.cardImages => (
        l10n.cardExportFormatCardImages,
        l10n.cardExportFormatCardImagesCaption,
      ),
    };
    return Semantics(
      inMutuallyExclusiveGroup: true,
      checked: isSelected,
      child: AppPressable(
        onTap: onTap,
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: context.typo.settingsTileLabel.copyWith(color: colors.settingsCardLabel),
                    ),
                    SizedBox(height: 4.h),
                    Text(caption, style: context.typo.caption.copyWith(color: colors.textSecondary)),
                  ],
                ),
              ),
              ElumCheckCircle(isChecked: isSelected),
            ],
          ),
        ),
      ),
    );
  }
}

/// 머리 글 + 칩 줄
class _ChipGroup extends StatelessWidget {
  const _ChipGroup({required this.header, required this.chips});

  final String header;
  final List<Widget> chips;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 16.w),
          child: Text(
            header,
            style: context.typo.settingsGroupLabel.copyWith(color: context.colors.settingsGroupLabel),
          ),
        ),
        SizedBox(height: 8.h),
        Wrap(spacing: 8.w, runSpacing: 8.h, children: chips),
      ],
    );
  }
}

/// 고르는 칩 (Pro 전용이면 작은 배지)
class _OptionChip extends StatelessWidget {
  const _OptionChip({
    required this.label,
    required this.isSelected,
    required this.onTap,
    this.isPro = false,
  });

  final String label;
  final bool isSelected;
  final bool isPro;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Semantics(
      button: true,
      selected: isSelected,
      child: AppPressable(
        onTap: onTap,
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 10.h),
          decoration: BoxDecoration(
            color: colors.surface,
            borderRadius: BorderRadius.circular(100.r),
            border: Border.all(
              color: isSelected ? colors.highlightBorder : colors.border,
              width: isSelected ? 2 : 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(label, style: context.typo.chipLabel.copyWith(color: colors.textPrimary)),
              if (isPro) ...[
                SizedBox(width: 6.w),
                const ProBadge(),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
