import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../core/l10n/l10n_context.dart';
import '../../../../core/theme/theme_context_ext.dart';
import '../../../../core/widgets/pro_upsell_button.dart';
import '../../../../core/widgets/settings_group.dart';
import '../../../../core/widgets/settings_switch_tile.dart';
import '../../../../core/widgets/settings_tile.dart';
import '../../domain/card_export_options.dart';
import 'card_export_choice_sheet.dart';

/// Free 가 잠긴 값을 고름 > 그 값으로 바꾼 설정 (Pro 미리 보기로만 그림, 내보내기 설정은 그대로)
typedef CardExportLockedPick = void Function(CardExportOptions previewOptions, CardExportLock lock);

/// 잠긴 값의 종류: 형태·배치(`cardExportAllLayouts`) · 디자인(`cardExportAllThemes`)
enum CardExportLock { layout, theme }

/// 내보내기 설정 (설정 화면 묶음 목록): 형태 > 배치(용지 방향 · 한 장에 · 카드 크기) > 꾸밈(디자인 · 카드 문장) > (Free) Pro 안내
///
/// 줄을 누르면 고르기 시트. Free 는 카드 한 장씩 · 기본 디자인만, 나머지는 Pro 배지와 함께 보이고 고르면 Pro 미리 보기
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

  /// 형태·배치를 모두 고를 수 있는가 (`cardExportAllLayouts`)
  final bool canUseAllLayouts;

  /// 디자인을 모두 고를 수 있는가 (`cardExportAllThemes`)
  final bool canUseAllThemes;

  /// 잠긴 형태·배치를 Pro 배지와 함께 보이는가 (살 수 없으면 숨김)
  final bool shouldShowProLayouts;

  /// 잠긴 디자인을 Pro 배지와 함께 보이는가 (살 수 없으면 숨김)
  final bool shouldShowProThemes;

  final CardExportLockedPick onLockedPick;

  /// 아래 Pro 안내의 버튼 (null 이면 안내를 그리지 않음)
  final VoidCallback? onUpsellTap;

  static const _groupGap = 20.0;

  /// Free 가 잠긴 배치 줄을 눌렀을 때 미리 보여 줄 오려 쓰는 카드 장수
  static const _lockedPreviewCardsPerPage = CardsPerPage.four;

  bool get _isLayoutLocked => !canUseAllLayouts;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    // 배치: 종이에 찍는 형태일 때, 또는 Free 에게 Pro 로 열리는 줄을 보일 때
    final shouldShowLayoutGroup = options.format.hasPaperLayout || (_isLayoutLocked && shouldShowProLayouts);
    final shouldShowPerPage = options.format == CardExportFormat.cutCards || _isLayoutLocked;
    final upsellTap = onUpsellTap;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SettingsGroup(
          children: [
            SettingsTile(
              label: l10n.cardExportFormatRow,
              valueText: formatLabelOf(context, options.format),
              showChevronWithValue: true,
              onTap: () => _pickFormat(context),
            ),
          ],
        ),
        if (shouldShowLayoutGroup) ...[
          SizedBox(height: _groupGap.h),
          SettingsGroup(
            header: l10n.cardExportLayoutSection,
            children: [
              SettingsTile(
                label: l10n.cardExportOrientationRow,
                valueText: _orientationLabel(context, options.orientation),
                showChevronWithValue: true,
                onTap: () => _pickOrientation(context),
              ),
              if (shouldShowPerPage)
                SettingsTile(
                  label: l10n.cardExportPerPageRow,
                  valueText: l10n.cardExportPerPage(options.cardsPerPage.count),
                  showChevronWithValue: true,
                  onTap: () => _pickCardsPerPage(context),
                ),
              SettingsTile(
                label: l10n.cardExportCardSizeRow,
                valueText: _cardSizeLabel(context, options.cardSize),
                showChevronWithValue: true,
                onTap: () => _pickCardSize(context),
              ),
            ],
          ),
        ],
        SizedBox(height: _groupGap.h),
        SettingsGroup(
          header: l10n.cardExportStyleSection,
          children: [
            SettingsTile(
              label: l10n.cardExportThemeSection,
              valueText: themeLabelOf(context, options.theme),
              showChevronWithValue: true,
              onTap: () => _pickTheme(context),
            ),
            SettingsSwitchTile(
              label: l10n.cardExportIncludeText,
              value: options.shouldIncludeText,
              onChanged: (value) => onChanged(options.copyWith(shouldIncludeText: value)),
            ),
          ],
        ),
        if (upsellTap != null) ...[
          SizedBox(height: _groupGap.h),
          _UpsellCard(onTap: upsellTap),
        ],
      ],
    );
  }

  // 고른 값 반영: 잠긴 값이면 Pro 미리 보기, 아니면 설정 변경
  void _apply(CardExportOptions next, {required bool isLocked, required CardExportLock lock}) {
    if (isLocked) {
      onLockedPick(next, lock);
      return;
    }
    onChanged(next);
  }

  Future<void> _pickFormat(BuildContext context) async {
    final l10n = context.l10n;
    final picked = await showCardExportChoiceSheet<CardExportFormat>(
      context: context,
      title: l10n.cardExportFormatSection,
      selected: options.format,
      choices: [
        for (final format in CardExportFormat.values)
          if (!_isFormatLocked(format) || shouldShowProLayouts)
            CardExportChoice(
              value: format,
              label: formatLabelOf(context, format),
              caption: _formatCaption(context, format),
              isLocked: _isFormatLocked(format),
            ),
      ],
    );
    if (picked == null || picked == options.format) return;
    _apply(options.copyWith(format: picked), isLocked: _isFormatLocked(picked), lock: CardExportLock.layout);
  }

  bool _isFormatLocked(CardExportFormat format) => _isLayoutLocked && format != CardExportFormat.cardImages;

  // 배치 줄 3개: Free 는 시트 없이 바로 Pro 미리 보기 (오려 쓰는 카드로 그 값을 보여 줌)
  Future<void> _pickOrientation(BuildContext context) async {
    if (_isLayoutLocked) {
      _showLockedLayout(options.copyWith(orientation: PaperOrientation.landscape));
      return;
    }
    final picked = await showCardExportChoiceSheet<PaperOrientation>(
      context: context,
      title: context.l10n.cardExportOrientationSheetTitle,
      selected: options.orientation,
      choices: [
        for (final orientation in PaperOrientation.values)
          CardExportChoice(value: orientation, label: _orientationLabel(context, orientation)),
      ],
    );
    if (picked != null) onChanged(options.copyWith(orientation: picked));
  }

  Future<void> _pickCardsPerPage(BuildContext context) async {
    if (_isLayoutLocked) {
      _showLockedLayout(options.copyWith(cardsPerPage: _lockedPreviewCardsPerPage));
      return;
    }
    final l10n = context.l10n;
    final picked = await showCardExportChoiceSheet<CardsPerPage>(
      context: context,
      title: l10n.cardExportPerPageSection,
      selected: options.cardsPerPage,
      choices: [
        for (final perPage in CardsPerPage.values)
          CardExportChoice(value: perPage, label: l10n.cardExportPerPage(perPage.count)),
      ],
    );
    if (picked != null) onChanged(options.copyWith(cardsPerPage: picked));
  }

  Future<void> _pickCardSize(BuildContext context) async {
    if (_isLayoutLocked) {
      _showLockedLayout(options.copyWith(cardSize: CardSize.medium));
      return;
    }
    final picked = await showCardExportChoiceSheet<CardSize>(
      context: context,
      title: context.l10n.cardExportCardSizeSheetTitle,
      selected: options.cardSize,
      choices: [
        for (final size in CardSize.values) CardExportChoice(value: size, label: _cardSizeLabel(context, size)),
      ],
    );
    if (picked != null) onChanged(options.copyWith(cardSize: picked));
  }

  // 배치는 종이에 찍는 형태에서만 보이므로 미리 보기는 오려 쓰는 카드로
  void _showLockedLayout(CardExportOptions next) =>
      onLockedPick(next.copyWith(format: CardExportFormat.cutCards), CardExportLock.layout);

  Future<void> _pickTheme(BuildContext context) async {
    final picked = await showCardExportChoiceSheet<CardDesignTheme>(
      context: context,
      title: context.l10n.cardExportThemeSection,
      selected: options.theme,
      choices: [
        for (final theme in CardDesignTheme.values)
          if (!_isThemeLocked(theme) || shouldShowProThemes)
            CardExportChoice(value: theme, label: themeLabelOf(context, theme), isLocked: _isThemeLocked(theme)),
      ],
    );
    if (picked == null || picked == options.theme) return;
    _apply(options.copyWith(theme: picked), isLocked: _isThemeLocked(picked), lock: CardExportLock.theme);
  }

  bool _isThemeLocked(CardDesignTheme theme) => theme.isProOnly && !canUseAllThemes;

  static String formatLabelOf(BuildContext context, CardExportFormat format) {
    final l10n = context.l10n;
    return switch (format) {
      CardExportFormat.routineSheet => l10n.cardExportFormatRoutineSheet,
      CardExportFormat.cutCards => l10n.cardExportFormatCutCards,
      CardExportFormat.cardImages => l10n.cardExportFormatCardImages,
    };
  }

  static String _formatCaption(BuildContext context, CardExportFormat format) {
    final l10n = context.l10n;
    return switch (format) {
      CardExportFormat.routineSheet => l10n.cardExportFormatRoutineSheetCaption,
      CardExportFormat.cutCards => l10n.cardExportFormatCutCardsCaption,
      CardExportFormat.cardImages => l10n.cardExportFormatCardImagesCaption,
    };
  }

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

  static String _orientationLabel(BuildContext context, PaperOrientation orientation) =>
      switch (orientation) {
        PaperOrientation.portrait => context.l10n.cardExportOrientationPortrait,
        PaperOrientation.landscape => context.l10n.cardExportOrientationLandscape,
      };

  static String _cardSizeLabel(BuildContext context, CardSize size) => switch (size) {
    CardSize.fit => context.l10n.cardExportCardSizeFit,
    CardSize.medium => context.l10n.cardExportCardSizeMedium,
    CardSize.small => context.l10n.cardExportCardSizeSmall,
  };
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
