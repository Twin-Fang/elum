import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../core/l10n/l10n_context.dart';
import '../../../../core/theme/theme_context_ext.dart';
import '../../../../core/widgets/coach_mark_parts.dart';
import '../../../../core/widgets/elum_check_circle.dart';
import '../../../../core/widgets/elum_error_code_text.dart';
import '../../../../core/widgets/elum_secondary_button.dart';
import '../../../../shared/models/routine.dart';
import '../../application/card_export_pictures.dart';
import '../../data/card_export_files.dart';
import '../../domain/card_export_options.dart';
import 'print_sheets.dart';

/// 카드 저장 미리 보기: (Pro 미리 보기) > 머리 > 종이 밖 안내 > 지면 한 장씩 옆으로 넘김 > 쪽 점 (#1461)
///
/// 지면 = 저장되는 그림 그대로. 넘기지 않은 지면도 굽게 전부 그려 둔다 (지연 생성 없음)
class CardExportPreview extends ConsumerStatefulWidget {
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
    this.teaser,
  });

  final Routine routine;
  final CardExportOptions options;
  final CardExportPictures pictures;
  final List<PrintSheet> sheets;

  /// 지면마다 굽기용 열쇠 ([sheets] 와 같은 차례, 화면이 들고 있음)
  final List<GlobalKey> sheetKeys;
  final bool hasWatermark;

  /// 워터마크 안내 글을 보이는가 (Pro 가 워터마크 없음을 줌 + 권유 대상)
  final bool shouldPromoteNoWatermark;
  final ValueChanged<String> onToggleCard;

  /// Free 가 잠긴 값을 골랐을 때 그 값의 Pro 미리 보기 판 ([CardExportProTeaser]), 없으면 null
  final Widget? teaser;

  @override
  ConsumerState<CardExportPreview> createState() => _CardExportPreviewState();
}

class _CardExportPreviewState extends ConsumerState<CardExportPreview> {
  static const _sectionGap = 24.0;
  static const _noticeGap = 6.0;
  static const _headerToPager = 12.0;
  static const _pagerToDots = 12.0;

  /// 지면을 그리는 높이 (폰에서 첫 장이 버튼 위에서 잘리지 않는 크기)
  static const _pagerHeight = 300.0;

  final _pagerController = ScrollController();
  int _pageIndex = 0;

  @override
  void initState() {
    super.initState();
    _pagerController.addListener(_onPagerScrolled);
  }

  @override
  void didUpdateWidget(CardExportPreview oldWidget) {
    super.didUpdateWidget(oldWidget);
    // 모양을 바꿔 쪽 수가 줄면 첫 쪽으로 (점이 범위를 넘지 않게)
    if (widget.sheets.length != oldWidget.sheets.length && _pagerController.hasClients) {
      _pagerController.jumpTo(0);
      _pageIndex = 0;
    }
  }

  @override
  void dispose() {
    _pagerController
      ..removeListener(_onPagerScrolled)
      ..dispose();
    super.dispose();
  }

  // 넘긴 위치 > 지금 쪽 (쪽 폭 = 보이는 폭)
  void _onPagerScrolled() {
    final position = _pagerController.position;
    if (position.viewportDimension <= 0) return;
    final page = (position.pixels / position.viewportDimension).round().clamp(0, widget.sheets.length - 1);
    if (page != _pageIndex) setState(() => _pageIndex = page);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colors = context.colors;
    final caption = context.typo.caption.copyWith(color: colors.textSecondary);
    final teaser = widget.teaser;
    final pictures = widget.pictures;
    final isCardImages = widget.options.format == CardExportFormat.cardImages;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (teaser != null) ...[
          teaser,
          SizedBox(height: _sectionGap.h),
        ],
        Row(
          children: [
            Expanded(
              child: Text(
                l10n.cardExportPreviewSection,
                style: context.typo.settingsGroupLabel.copyWith(color: colors.settingsGroupLabel),
              ),
            ),
            if (isCardImages) Text(l10n.cardExportPreviewToggleHint, style: caption),
          ],
        ),
        // 안내는 종이 밖에만 (미리 보기의 종이 = 저장되는 그림 그대로)
        if (pictures.failedCount > 0) ...[
          SizedBox(height: _noticeGap.h),
          Text(l10n.cardExportSomePicturesFailed(pictures.failedCount), style: caption),
          Align(
            alignment: Alignment.centerLeft,
            child: ElumSecondaryButton(
              label: l10n.commonRetry,
              onTap: () => retryCardExportPictures(ref, widget.routine, pictures),
              isCompact: true,
            ),
          ),
          const ElumErrorCodeText(CardExportErrorCode.image, textAlign: TextAlign.left),
        ],
        if (pictures.hasMissingPicture) ...[
          SizedBox(height: _noticeGap.h),
          Text(l10n.cardExportMissingPicture, style: caption),
        ],
        if (widget.hasWatermark && widget.shouldPromoteNoWatermark) ...[
          SizedBox(height: _noticeGap.h),
          Text(l10n.cardExportWatermarkNotice, style: caption),
        ],
        SizedBox(height: _headerToPager.h),
        _pager(),
        if (widget.sheets.length > 1) ...[
          SizedBox(height: _pagerToDots.h),
          Center(child: CoachDots(count: widget.sheets.length, index: _pageIndex)),
        ],
      ],
    );
  }

  // 한 쪽 = 보이는 폭 전체 (가운데 지면) > 쪽 단위로 멈춤
  Widget _pager() {
    return SizedBox(
      height: _pagerHeight.h,
      child: LayoutBuilder(
        builder: (context, constraints) => SingleChildScrollView(
          controller: _pagerController,
          scrollDirection: Axis.horizontal,
          physics: const PageScrollPhysics(),
          child: Row(
            children: [
              for (final (index, sheet) in widget.sheets.indexed)
                SizedBox(
                  width: constraints.maxWidth,
                  child: Center(
                    child: _PreviewSheet(
                      sheet: sheet,
                      boundaryKey: widget.sheetKeys[index],
                      isExcluded: sheet.cardId != null && widget.options.excludedCardIds.contains(sheet.cardId),
                      onToggle: switch (sheet.cardId) {
                        final cardId? => () => widget.onToggleCard(cardId),
                        null => null,
                      },
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 미리 보기 한 장: 칸에 맞춰 줄여 보이되, 굽는 것은 원래 크기 지면. 카드 한 장씩이면 카드 안쪽 위 ✓
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

  /// 뺀 지면 흐림
  static const _excludedOpacity = 0.4;
  static const _checkInset = 10.0;

  @override
  Widget build(BuildContext context) {
    // 지면 비율 상자 > ✓ 가 지면 안쪽 모서리에 붙음
    final page = AspectRatio(
      aspectRatio: sheet.size.aspectRatio,
      child: DecoratedBox(
        decoration: BoxDecoration(border: Border.all(color: context.colors.border)),
        child: FittedBox(
          fit: BoxFit.contain,
          child: RepaintBoundary(
            key: boundaryKey,
            child: SizedBox.fromSize(size: sheet.size, child: sheet.page),
          ),
        ),
      ),
    );
    final onToggle = this.onToggle;
    if (onToggle == null) return page;
    return Semantics(
      button: true,
      selected: !isExcluded,
      child: GestureDetector(
        onTap: onToggle,
        child: AspectRatio(
          aspectRatio: sheet.size.aspectRatio,
          child: Stack(
            fit: StackFit.expand,
            children: [
              Opacity(opacity: isExcluded ? _excludedOpacity : 1, child: page),
              Positioned(
                top: _checkInset.w,
                right: _checkInset.w,
                child: ElumCheckCircle(isChecked: !isExcluded),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
