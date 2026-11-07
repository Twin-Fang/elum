import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../core/l10n/l10n_context.dart';
import '../../../../core/theme/theme_context_ext.dart';
import '../../../../core/widgets/elum_check_circle.dart';
import '../../../../core/widgets/elum_error_code_text.dart';
import '../../../../core/widgets/elum_text_link.dart';
import '../../../../core/widgets/pro_upsell_button.dart';
import '../../../../shared/models/routine.dart';
import '../../../subscription/application/plan_paywall_entry.dart';
import '../../application/card_export_pictures.dart';
import '../../data/card_export_files.dart';
import '../../domain/card_export_options.dart';
import 'card_export_theme_teaser.dart';
import 'print_sheets.dart';

/// 인쇄용 미리 보기: (Pro 테마 흐린 미리 보기) > 종이 밖 안내 > 지면들 (= 굽는 파일 그대로)
class CardExportPreview extends ConsumerWidget {
  const CardExportPreview({
    super.key,
    required this.routine,
    required this.options,
    required this.pictures,
    required this.sheets,
    required this.sheetKeys,
    required this.hasWatermark,
    required this.shouldPromoteNoWatermark,
    required this.onToggleCard,
    this.teaserSheet,
  });

  static const _sectionGap = 24.0;
  static const _pageGap = 16.0;

  final Routine routine;
  final CardExportOptions options;
  final CardExportPictures pictures;
  final List<PrintSheet> sheets;

  /// 지면마다 굽기용 열쇠 ([sheets] 와 같은 차례, 화면이 들고 있음)
  final List<GlobalKey> sheetKeys;
  final bool hasWatermark;
  /// 워터마크 줄 아래 `Pro 알아보기` 를 보이는가 (Pro 가 워터마크 없음을 줌 + 권유 대상)
  final bool shouldPromoteNoWatermark;
  final ValueChanged<String> onToggleCard;

  /// Free 가 흐리게 보고 있는 Pro 테마의 첫 지면, 없으면 null
  final PrintSheet? teaserSheet;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final colors = context.colors;
    final caption = context.typo.caption.copyWith(color: colors.textSecondary);
    final teaser = teaserSheet;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (teaser != null) ...[
          CardExportThemeTeaser(
            sheet: teaser,
            onUnlock: () => openPlanPaywall(context, ref),
          ),
          SizedBox(height: _sectionGap.h),
        ],
        Text(
          l10n.cardExportPreviewSection,
          style: context.typo.settingsGroupLabel.copyWith(color: colors.settingsGroupLabel),
        ),
        // 안내는 종이 밖에만 (미리 보기의 종이 = 파일 그대로)
        if (pictures.failedCount > 0) ...[
          SizedBox(height: 6.h),
          Text(l10n.cardExportSomePicturesFailed(pictures.failedCount), style: caption),
          Align(
            alignment: Alignment.centerLeft,
            child: ElumTextLink(
              label: l10n.commonRetry,
              onTap: () => retryCardExportPictures(ref, routine, pictures),
            ),
          ),
          const ElumErrorCodeText(CardExportErrorCode.image, textAlign: TextAlign.left),
        ],
        if (pictures.hasMissingPicture) ...[
          SizedBox(height: 6.h),
          Text(l10n.cardExportMissingPicture, style: caption),
        ],
        if (hasWatermark && shouldPromoteNoWatermark) ...[
          SizedBox(height: 6.h),
          Text(l10n.cardExportWatermarkNotice, style: caption),
          Align(
            alignment: Alignment.centerLeft,
            child: ProUpsellButton(
              style: ProUpsellStyle.link,
              onTap: () => openPlanPaywall(context, ref),
            ),
          ),
        ],
        if (options.format != CardExportFormat.cardImages) ...[
          SizedBox(height: 6.h),
          Text(l10n.cardExportActualSizeHint, style: caption),
        ],
        SizedBox(height: 12.h),
        for (final (index, sheet) in sheets.indexed) ...[
          if (index > 0) SizedBox(height: _pageGap.h),
          _PreviewSheet(
            sheet: sheet,
            boundaryKey: sheetKeys[index],
            isExcluded: sheet.cardId != null && options.excludedCardIds.contains(sheet.cardId),
            onToggle: switch (sheet.cardId) {
              final cardId? => () => onToggleCard(cardId),
              null => null,
            },
          ),
        ],
      ],
    );
  }
}

/// 미리 보기 한 장: 화면 폭에 맞춰 줄여 보이되, 굽는 것은 원래 크기 지면
class _PreviewSheet extends StatelessWidget {
  const _PreviewSheet({
    required this.sheet,
    required this.boundaryKey,
    required this.isExcluded,
    this.onToggle,
  });

  final PrintSheet sheet;
  final GlobalKey boundaryKey;
  final bool isExcluded;

  /// 카드 한 장씩: 눌러서 빼고 넣기
  final VoidCallback? onToggle;

  @override
  Widget build(BuildContext context) {
    final page = DecoratedBox(
      decoration: BoxDecoration(border: Border.all(color: context.colors.border)),
      child: FittedBox(
        fit: BoxFit.contain,
        child: RepaintBoundary(
          key: boundaryKey,
          child: SizedBox.fromSize(size: sheet.size, child: sheet.page),
        ),
      ),
    );
    if (onToggle == null) return page;
    return GestureDetector(
      onTap: onToggle,
      child: Stack(
        children: [
          Opacity(opacity: isExcluded ? 0.4 : 1, child: page),
          Positioned(
            top: 8.w,
            right: 8.w,
            child: ElumCheckCircle(isChecked: !isExcluded),
          ),
        ],
      ),
    );
  }
}
