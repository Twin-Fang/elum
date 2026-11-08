import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../../core/assets/app_assets.dart';
import '../../../../core/l10n/l10n_context.dart';
import '../../../../core/layout/share_origin.dart';
import '../../../../core/logger/app_logger.dart';
import '../../../../core/theme/theme_context_ext.dart';
import '../../../../core/widgets/elum_dialog.dart';
import '../../../../core/widgets/elum_error_view.dart';
import '../../../../core/widgets/elum_scaffold.dart';
import '../../../../core/widgets/elum_button.dart';
import '../../../../core/widgets/elum_sheet_action_row.dart';
import '../../../../core/widgets/elum_state_body.dart';
import '../../../../core/widgets/elum_spinner.dart';
import '../../../../core/widgets/show_failure.dart';
import '../../../../shared/models/routine.dart';
import '../../../../shared/pictogram/pictogram_svg_loader.dart';
import '../../../member/application/plan_access.dart';
import '../../../subscription/application/plan_paywall_entry.dart';
import '../../../subscription/domain/plan_benefit.dart';
import '../../application/card_export_pictures.dart';
import '../../data/card_export_files.dart';
import '../../domain/card_export_options.dart';
import 'card_export_options_panel.dart';
import 'card_export_preview.dart';
import 'print_sheets.dart';

/// 인쇄용으로 받기: 설정 > 미리 보기(= 파일 그대로) > 보내기 · 인쇄하기 (#1073)
///
/// Free 는 이룸 로고·워터마크가 들어가고, Pro 는 워터마크 없음 + 디자인 테마 전부.
class CardExportScreen extends ConsumerStatefulWidget {
  const CardExportScreen({super.key, required this.routine});

  final Routine routine;

  @override
  ConsumerState<CardExportScreen> createState() => _CardExportScreenState();
}

class _CardExportScreenState extends ConsumerState<CardExportScreen> {
  static const _backTop = ElumScaffold.settingsBackTop;
  static const _horizontalPadding = 16.0;
  static const _sectionGap = 24.0;
  static const _files = CardExportFiles();

  CardExportOptions _options = const CardExportOptions();

  /// Free 가 미리 보기로 보고 있는 Pro 테마 (판매 중일 때만). 다른 칩을 고르면 지움
  CardDesignTheme? _teaserTheme;
  bool _isBusy = false;
  bool _isArtReady = false;
  CardExportPictures? _precached;
  final _sheetKeys = <GlobalKey>[];

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final access = ref.watch(planAccessProvider);
    final picturesAsync = ref.watch(cardExportPicturesProvider(widget.routine));
    final pictures = picturesAsync.value;
    if (pictures != null && !identical(pictures, _precached)) {
      _precached = pictures;
      _precacheArt(pictures);
    }
    // 그림 몇 장을 못 받아도 내보냄 (그 카드는 대체 그림·제목으로, 종이 밖에 한 줄 안내)
    final canExport = pictures != null && _isArtReady && !_isBusy;
    return ElumScaffold(
      onBack: () => Navigator.of(context).pop(),
      title: l10n.cardExportOpen,
      backTop: _backTop,
      horizontalPadding: _horizontalPadding,
      bottomButton: widget.routine.steps.isEmpty
          ? null
          : _bottomButtons(l10n, canExport: canExport, isLoading: _isBusy || (pictures == null && !picturesAsync.hasError)),
      // 카드 없는 일과: 남는 높이 가운데 빈 상태 (위 왼쪽 한 줄로 두지 않음)
      child: widget.routine.steps.isEmpty
          ? ElumStateBody(child: ElumErrorView(message: l10n.cardExportNoCards, compact: true))
          : SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(height: _sectionGap.h),
              CardExportOptionsPanel(
                options: _options,
                onChanged: (next) => setState(() {
                  _options = next;
                  _teaserTheme = null;
                }),
                canUseAllThemes: access.canUseAllCardDesignThemes,
                shouldShowProThemes: access.shouldShowEntryFor(PlanBenefit.cardExportAllThemes),
                teaserTheme: _teaserTheme,
                // Free · 판매 중이면 Pro 미리 보기, 살 수만 있으면 요금제 화면, 아니면 안내만
                onLockedThemeTap: (theme) => _onLockedThemeTap(access, theme),
              ),
              SizedBox(height: _sectionGap.h),
              _preview(
                context,
                picturesAsync,
                hasWatermark: !access.canExportCardsWithoutWatermark,
                shouldPromoteNoWatermark: access.shouldPromoteBenefit(PlanBenefit.cardExportWithoutWatermark),
              ),
            SizedBox(height: _sectionGap.h),
          ],
        ),
      ),
    );
  }

  /// 아래 버튼: 카드 한 장씩(이미지) > `보내기` 하나 · 그 외 > `인쇄하기` + `보내기`
  Widget _bottomButtons(AppLocalizations l10n, {required bool canExport, required bool isLoading}) {
    if (_options.format == CardExportFormat.cardImages) {
      return ElumButton(
        label: l10n.cardExportShare,
        loading: isLoading,
        onPressed: canExport ? () => _export(shouldPrint: false) : () {},
      );
    }
    return ElumSheetActionRow(
      cancelLabel: l10n.cardExportPrint,
      onCancel: canExport ? () => _export(shouldPrint: true) : null,
      confirmLabel: l10n.cardExportShare,
      onConfirm: canExport ? () => _export(shouldPrint: false) : () {},
      isLoading: isLoading,
    );
  }

  Widget _preview(
    BuildContext context,
    AsyncValue<CardExportPictures> picturesAsync, {
    required bool hasWatermark,
    required bool shouldPromoteNoWatermark,
  }) {
    final l10n = context.l10n;
    final colors = context.colors;
    final pictures = picturesAsync.value;
    if (pictures == null && !picturesAsync.hasError) {
      return Column(children: [
        ElumSpinner(size: 32.w, strokeWidth: 3),
        SizedBox(height: 12.h),
        Text(l10n.cardExportPreparing, style: context.typo.body.copyWith(color: colors.textSecondary)),
      ]);
    }
    if (pictures == null) {
      return ElumErrorView(
        message: l10n.cardExportImageFailed,
        errorCode: CardExportErrorCode.image,
        onRetry: () => ref.invalidate(cardExportPicturesProvider(widget.routine)),
        compact: true,
      );
    }
    final sheets = buildPrintSheets(
      routine: widget.routine,
      options: _options,
      pictures: pictures,
      hasWatermark: hasWatermark,
    );
    while (_sheetKeys.length < sheets.length) {
      _sheetKeys.add(GlobalKey());
    }
    final teaserTheme = _teaserTheme;
    final teaserSheets = teaserTheme == null
        ? const <PrintSheet>[]
        : buildPrintSheets(
            routine: widget.routine,
            options: _options.copyWith(theme: teaserTheme),
            pictures: pictures,
            hasWatermark: hasWatermark,
          );
    return CardExportPreview(
      routine: widget.routine,
      options: _options,
      pictures: pictures,
      sheets: sheets,
      sheetKeys: _sheetKeys,
      hasWatermark: hasWatermark,
      shouldPromoteNoWatermark: shouldPromoteNoWatermark,
      onToggleCard: _toggleCard,
      teaserSheet: teaserSheets.isEmpty ? null : teaserSheets.first,
    );
  }

  void _onLockedThemeTap(PlanAccess access, CardDesignTheme theme) {
    if (access.shouldPromoteBenefit(PlanBenefit.cardExportAllThemes)) {
      // 같은 칩을 다시 누르면 미리 보기를 닫음
      setState(() => _teaserTheme = _teaserTheme == theme ? null : theme);
      return;
    }
    openProOnlyNotice(context, ref, title: context.l10n.cardExportProThemeLocked);
  }

  void _toggleCard(String cardId) {
    final excluded = {..._options.excludedCardIds};
    excluded.contains(cardId) ? excluded.remove(cardId) : excluded.add(cardId);
    setState(() => _options = _options.copyWith(excludedCardIds: excluded));
  }

  // 번들 그림(예시 이미지 · 픽토그램)을 미리 읽어 둔다 — 덜 읽힌 채 구우면 빈 칸이 찍힘
  Future<void> _precacheArt(CardExportPictures pictures) async {
    setState(() => _isArtReady = false);
    try {
      for (final picture in pictures.byCardId.values) {
        if (picture.bytes case final bytes?) {
          await precacheImage(MemoryImage(bytes), context);
        } else if (picture.exampleImageId case final id?) {
          await precacheImage(AssetImage(AppAssets.exampleRoutineImage(id)), context);
        } else if (picture.pictogramId case final id?) {
          final loader = PictogramSvgLoader(id);
          await svg.cache.putIfAbsent(loader.cacheKey(null), () => loader.loadBytes(null));
        }
        if (!mounted) return;
      }
    } on Object catch (error) {
      // 미리 읽기 실패는 막지 않는다 — 그 그림은 그릴 때 대체 그림(제목)으로 내려감
      AppLogger.error('card export precache failed', error);
    }
    if (mounted) setState(() => _isArtReady = true);
  }

  // 미리 보기 지면 굽기 > PNG(카드 한 장씩) 또는 PDF > 보내기 · 인쇄
  Future<void> _export({required bool shouldPrint}) async {
    final l10n = context.l10n;
    final origin = shareOriginOf(context);
    final pictures = _precached;
    if (pictures == null) return;
    final sheets = buildPrintSheets(
      routine: widget.routine,
      options: _options,
      pictures: pictures,
      hasWatermark: !ref.read(planAccessProvider).canExportCardsWithoutWatermark,
    );
    final included = [
      for (final (index, sheet) in sheets.indexed)
        if (sheet.cardId == null || !_options.excludedCardIds.contains(sheet.cardId)) (index, sheet),
    ];
    if (included.isEmpty) {
      await showElumDialog<void>(
        context: context,
        title: l10n.cardExportNoneSelected,
        actions: [ElumDialogAction(label: l10n.commonConfirm)],
      );
      return;
    }
    setState(() => _isBusy = true);
    try {
      await WidgetsBinding.instance.endOfFrame;
      final pngs = <Uint8List>[];
      for (final (index, sheet) in included) {
        final boundary = _sheetKeys[index].currentContext?.findRenderObject();
        if (boundary is! RenderRepaintBoundary) throw StateError('sheet $index not painted');
        pngs.add(await _files.capturePng(boundary, sheet.pixelRatio));
      }
      final stem = exportFileStem(widget.routine.title);
      if (_options.format == CardExportFormat.cardImages) {
        await _files.share(
          files: [
            for (final (index, png) in pngs.indexed)
              (fileName: '${stem}_${(index + 1).toString().padLeft(2, '0')}.png', bytes: png, mimeType: 'image/png'),
          ],
          sharePositionOrigin: origin,
        );
        return;
      }
      final pdf = await _files.buildA4Pdf(pngs);
      if (shouldPrint) {
        final printOutcome = await _files.printPdf(pdf: pdf, jobName: stem);
        // 취소는 오류가 아님 > 인쇄 서비스가 없을 때만 안내
        if (printOutcome == CardPrintOutcome.unavailable && mounted) {
          await showFailureMessage(
            context,
            sentence: l10n.cardExportPrintFailed,
            code: CardExportErrorCode.print,
          );
        }
        return;
      }
      await _files.share(
        files: [(fileName: '$stem.pdf', bytes: pdf, mimeType: 'application/pdf')],
        sharePositionOrigin: origin,
      );
    } on Object catch (error) {
      if (!mounted) return;
      await showFailure(
        context,
        error,
        fallback: l10n.cardExportRenderFailed,
        fallbackCode: CardExportErrorCode.render,
      );
    } finally {
      if (mounted) setState(() => _isBusy = false);
    }
  }
}
