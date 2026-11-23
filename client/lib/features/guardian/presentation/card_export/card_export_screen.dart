import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../../core/assets/app_assets.dart';
import '../../../../core/l10n/l10n_context.dart';
import '../../../../core/logger/app_logger.dart';
import '../../../../core/theme/theme_context_ext.dart';
import '../../../../core/widgets/elum_button.dart';
import '../../../../core/widgets/elum_dialog.dart';
import '../../../../core/widgets/elum_error_view.dart';
import '../../../../core/widgets/elum_scaffold.dart';
import '../../../../core/widgets/elum_spinner.dart';
import '../../../../core/widgets/elum_state_body.dart';
import '../../../../core/widgets/elum_toast.dart';
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
import 'card_export_pro_teaser.dart';
import 'print_sheets.dart';

/// 카드 저장하기: 미리 보기(= 저장되는 그림 그대로) > 모양 · 꾸미기 > 저장하기 하나 > 사진 앱 (#1073 · #1461)
///
/// Free 는 카드 한 장씩 · 기본 디자인 + 이룸 로고 띠, Pro 는 모양·배치·디자인 전부 + 띠 없음.
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

  /// Free 가 Pro 미리 보기로 보고 있는 잠긴 설정 (판매 중일 때만). 다른 값을 고르면 지움
  ({CardExportOptions options, CardExportLock lock})? _teaser;
  bool _isBusy = false;
  bool _isArtReady = false;
  CardExportPictures? _precached;
  final _sheetKeys = <GlobalKey>[];

  /// Pro 미리 보기 판 자리 (고른 뒤 화면 안으로 스크롤)
  final _teaserKey = GlobalKey();

  /// Pro 미리 보기 판으로 스크롤하는 시간
  static const _teaserScrollDuration = Duration(milliseconds: 300);

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final access = ref.watch(planAccessProvider);
    // 권한 밖 값은 Free 값으로 (Pro 가 끝난 뒤 남은 설정이 미리 보기·저장으로 나가지 않게)
    final options = _options.limitedTo(
      canUseAllLayouts: access.canUseAllCardExportLayouts,
      canUseAllThemes: access.canUseAllCardDesignThemes,
    );
    final hasWatermark = !access.canExportCardsWithoutWatermark;
    final picturesAsync = ref.watch(cardExportPicturesProvider(widget.routine));
    final pictures = picturesAsync.value;
    if (pictures != null && !identical(pictures, _precached)) {
      _precached = pictures;
      _precacheArt(pictures);
    }
    // 지면은 여기서 한 번 만들어 미리 보기 · 저장 장수가 같이 씀
    final sheets = pictures == null
        ? const <PrintSheet>[]
        : buildPrintSheets(routine: widget.routine, options: options, pictures: pictures, hasWatermark: hasWatermark);
    // 그림 몇 장을 못 받아도 저장함 (그 카드는 대체 그림·제목으로, 종이 밖에 한 줄 안내)
    final canSave = pictures != null && _isArtReady && !_isBusy;
    return ElumScaffold(
      onBack: () => Navigator.of(context).pop(),
      title: l10n.cardExportOpen,
      backTop: _backTop,
      horizontalPadding: _horizontalPadding,
      bottomButton: widget.routine.steps.isEmpty
          ? null
          : ElumButton(
              label: l10n.cardExportSaveCount(_includedSheetsOf(sheets, options).length),
              loading: _isBusy || (pictures == null && !picturesAsync.hasError),
              // 준비 전에는 눌러도 아무 일 없음 (회색으로 바꾸지 않음: 준비 중 스피너가 이미 보임)
              onPressed: canSave ? () => _save(sheets, options) : () {},
            ),
      // 카드 없는 일과: 남는 높이 가운데 빈 상태 (위 왼쪽 한 줄로 두지 않음)
      child: widget.routine.steps.isEmpty
          ? ElumStateBody(child: ElumErrorView(message: l10n.cardExportNoCards, compact: true))
          : SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SizedBox(height: _sectionGap.h),
                  _preview(
                    context,
                    picturesAsync,
                    options,
                    sheets,
                    hasWatermark: hasWatermark,
                    shouldPromoteNoWatermark: access.shouldPromoteBenefit(PlanBenefit.cardExportWithoutWatermark),
                  ),
                  SizedBox(height: _sectionGap.h),
                  CardExportOptionsPanel(
                    options: options,
                    onChanged: (next) => setState(() {
                      _options = next;
                      _teaser = null;
                    }),
                    canUseAllLayouts: access.canUseAllCardExportLayouts,
                    canUseAllThemes: access.canUseAllCardDesignThemes,
                    shouldShowProLayouts: access.shouldShowEntryFor(PlanBenefit.cardExportAllLayouts),
                    shouldShowProThemes: access.shouldShowEntryFor(PlanBenefit.cardExportAllThemes),
                    // Free · 판매 중이면 Pro 미리 보기, 아니면 안내만
                    onLockedPick: (previewOptions, lock) => _onLockedPick(access, previewOptions, lock),
                    onUpsellTap: access.shouldPromoteBenefit(PlanBenefit.cardExportAllLayouts)
                        ? () => openPlanPaywall(context, ref, highlight: PlanBenefit.cardExportAllLayouts)
                        : null,
                  ),
                  SizedBox(height: _sectionGap.h),
                ],
              ),
            ),
    );
  }

  /// 저장할 지면 (차례, 지면): 카드 한 장씩에서 뺀 카드 제외
  List<(int, PrintSheet)> _includedSheetsOf(List<PrintSheet> sheets, CardExportOptions options) => [
    for (final (index, sheet) in sheets.indexed)
      if (sheet.cardId == null || !options.excludedCardIds.contains(sheet.cardId)) (index, sheet),
  ];

  Widget _preview(
    BuildContext context,
    AsyncValue<CardExportPictures> picturesAsync,
    CardExportOptions options,
    List<PrintSheet> sheets, {
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
    while (_sheetKeys.length < sheets.length) {
      _sheetKeys.add(GlobalKey());
    }
    return CardExportPreview(
      routine: widget.routine,
      options: options,
      pictures: pictures,
      sheets: sheets,
      sheetKeys: _sheetKeys,
      hasWatermark: hasWatermark,
      shouldPromoteNoWatermark: shouldPromoteNoWatermark,
      onToggleCard: _toggleCard,
      teaser: _teaserOf(context, pictures, hasWatermark: hasWatermark),
    );
  }

  // 잠긴 설정의 첫 지면 > Pro 미리 보기 판 (모양·배치 / 디자인 문구)
  Widget? _teaserOf(BuildContext context, CardExportPictures pictures, {required bool hasWatermark}) {
    final teaser = _teaser;
    if (teaser == null) return null;
    final teaserSheets = buildPrintSheets(
      routine: widget.routine,
      options: teaser.options,
      pictures: pictures,
      hasWatermark: hasWatermark,
    );
    if (teaserSheets.isEmpty) return null;
    final l10n = context.l10n;
    final isLayout = teaser.lock == CardExportLock.layout;
    return CardExportProTeaser(
      key: _teaserKey,
      sheet: teaserSheets.first,
      title: isLayout ? l10n.proTeaserCardLayoutTitle : l10n.proTeaserCardThemeTitle,
      benefit: isLayout ? l10n.proTeaserCardLayoutBenefit : l10n.proTeaserCardThemeBenefit,
      actions: watchProUpsellActions(
        context,
        ref,
        highlight: isLayout ? PlanBenefit.cardExportAllLayouts : PlanBenefit.cardExportAllThemes,
      ),
    );
  }

  // 잠긴 값 고름: 판매 중 > Pro 미리 보기(판까지 스크롤) · 아니면 Pro 안내
  void _onLockedPick(PlanAccess access, CardExportOptions previewOptions, CardExportLock lock) {
    final benefit = lock == CardExportLock.layout ? PlanBenefit.cardExportAllLayouts : PlanBenefit.cardExportAllThemes;
    if (access.shouldPromoteBenefit(benefit)) {
      setState(() => _teaser = (options: previewOptions, lock: lock));
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final teaserContext = _teaserKey.currentContext;
        if (teaserContext != null && teaserContext.mounted) {
          Scrollable.ensureVisible(teaserContext, duration: _teaserScrollDuration);
        }
      });
      return;
    }
    openProOnlyNotice(
      context,
      ref,
      title: lock == CardExportLock.layout ? context.l10n.cardExportProLayoutLocked : context.l10n.cardExportProThemeLocked,
      benefit: benefit,
    );
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

  // 저장: 고른 카드 확인 > 지면 굽기(PNG) > 사진 앱 > 결과 안내
  Future<void> _save(List<PrintSheet> sheets, CardExportOptions options) async {
    final l10n = context.l10n;
    final included = _includedSheetsOf(sheets, options);
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
      final pngs = await _capturePngs(included);
      final outcome = await _files.saveToPhotos(pngs: pngs, fileStem: exportFileStem(widget.routine.title));
      if (!mounted) return;
      await _showSaveOutcome(outcome, savedCount: pngs.length);
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

  // 미리 보기에 그려진 지면 > PNG (지면 원래 크기 × 배율)
  Future<List<Uint8List>> _capturePngs(List<(int, PrintSheet)> included) async {
    await WidgetsBinding.instance.endOfFrame;
    final pngs = <Uint8List>[];
    for (final (index, sheet) in included) {
      final boundary = _sheetKeys[index].currentContext?.findRenderObject();
      if (boundary is! RenderRepaintBoundary) throw StateError('sheet $index not painted');
      pngs.add(await _files.capturePng(boundary, sheet.pixelRatio));
    }
    return pngs;
  }

  // 저장 결과 3개: 토스트 · 권한 거부(설정 열기) · 실패 팝업
  Future<void> _showSaveOutcome(CardSaveOutcome outcome, {required int savedCount}) async {
    final l10n = context.l10n;
    switch (outcome) {
      case CardSaveOutcome.saved:
        showElumToast(context, l10n.cardExportSaved(savedCount));
      case CardSaveOutcome.permissionDenied:
        final shouldOpenSettings = await showElumDialog<bool>(
          context: context,
          title: l10n.cardExportSaveDenied,
          code: CardExportErrorCode.saveDenied,
          actions: [
            ElumDialogAction(label: l10n.commonCancel, value: false),
            ElumDialogAction(label: l10n.cardExportOpenSettings, value: true),
          ],
        );
        if (shouldOpenSettings == true) await _files.openAppSettings();
      case CardSaveOutcome.failed:
        await showFailureMessage(context, sentence: l10n.cardExportSaveFailed, code: CardExportErrorCode.save);
    }
  }
}
