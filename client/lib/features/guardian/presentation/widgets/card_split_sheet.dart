import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../core/l10n/l10n_context.dart';
import '../../../../core/network/app_failure.dart';
import '../../../../core/theme/theme_context_ext.dart';
import '../../../../core/widgets/elum_bottom_sheet.dart';
import '../../../../core/widgets/elum_button.dart';
import '../../../../core/widgets/elum_sheet_action_row.dart';
import '../../../../core/widgets/elum_sheet_frame.dart';
import '../../../../core/widgets/elum_spinner.dart';
import '../../../subscription/application/plan_paywall_entry.dart';
import '../../application/card_split_controller.dart';
import '../../domain/card_split.dart';

/// 화면 오류 코드 (서버 코드가 없을 때)
const cardSplitErrorCode = 'E-CARD-SPLIT';

/// 카드 나누기 시트: 나누는 중 > 안(원래 카드 + 나눈 카드 2~3장) > 그대로 두기 · 이렇게 나누기
/// 이미 짧으면 한 문장 + 확인, 실패면 오류 코드 + 다시 하기 · 닫기. 고르기 전에는 카드가 바뀌지 않음
class CardSplitSheet extends ConsumerStatefulWidget {
  const CardSplitSheet({
    super.key,
    required this.routineId,
    required this.stepId,
    required this.originalTitle,
  });

  final String routineId;
  final String stepId;

  /// 위에 흐리게 보일 원래 카드 한 줄
  final String originalTitle;

  /// 나눴으면 새 카드 수, 그대로 두거나 닫았으면 null
  static Future<int?> show(
    BuildContext context, {
    required String routineId,
    required String stepId,
    required String originalTitle,
  }) => showElumSheet<int>(
    context: context,
    builder: (_) => CardSplitSheet(routineId: routineId, stepId: stepId, originalTitle: originalTitle),
  );

  @override
  ConsumerState<CardSplitSheet> createState() => _CardSplitSheetState();
}

enum _SplitPhase { loading, suggested, alreadyShort, failed }

class _CardSplitSheetState extends ConsumerState<CardSplitSheet> {
  var _phase = _SplitPhase.loading;
  var _isApplying = false;
  List<CardSplitDraft> _drafts = const [];
  AppFailure? _failure;

  @override
  void initState() {
    super.initState();
    _loadSuggestion();
  }

  /// 안 받기 (저장 없음)
  Future<void> _loadSuggestion() async {
    setState(() {
      _phase = _SplitPhase.loading;
      _failure = null;
    });
    final result = await ref.read(cardSplitControllerProvider).suggest(
      routineId: widget.routineId,
      stepId: widget.stepId,
    );
    if (!mounted) return;
    final suggestion = result.suggestion;
    switch (suggestion) {
      case CardSplitSuggested(:final drafts):
        setState(() {
          _drafts = drafts;
          _phase = _SplitPhase.suggested;
        });
      case CardSplitAlreadyShort():
        setState(() => _phase = _SplitPhase.alreadyShort);
      case null:
        await _fail(result.failure);
    }
  }

  /// 안 적용 > 성공하면 새 카드 수와 함께 닫기
  Future<void> _applySuggestion() async {
    if (_isApplying) return;
    setState(() {
      _isApplying = true;
      _failure = null;
    });
    final result = await ref.read(cardSplitControllerProvider).apply(
      routineId: widget.routineId,
      stepId: widget.stepId,
      drafts: _drafts,
    );
    if (!mounted) return;
    if (result.failure == null) {
      Navigator.of(context).pop(result.addedCount);
      return;
    }
    setState(() => _isApplying = false);
    await _fail(result.failure);
  }

  /// 실패: Pro 거절이면 요금제 안내 후 닫기, 아니면 오류 코드와 함께 실패 화면
  Future<void> _fail(AppFailure? failure) async {
    if (await handleProOnlyRejection(context, ref, failure)) {
      if (mounted) Navigator.of(context).pop();
      return;
    }
    if (!mounted) return;
    setState(() {
      _failure = failure ?? const AppFailure(fault: NetworkFault.app);
      _phase = _SplitPhase.failed;
    });
  }

  /// 다시 하기: 안을 받았으면 적용부터, 아니면 안 받기부터
  void _retry() => _drafts.isEmpty ? _loadSuggestion() : _applySuggestion();

  @override
  Widget build(BuildContext context) {
    return PopScope(
      // 적용하는 동안은 내려 닫지 못하게 (카드가 바뀌는 중)
      canPop: !_isApplying,
      child: switch (_phase) {
        _SplitPhase.loading => _loadingFrame(context),
        _SplitPhase.suggested => _suggestedFrame(context),
        _SplitPhase.alreadyShort => _alreadyShortFrame(context),
        _SplitPhase.failed => _failedFrame(context),
      },
    );
  }

  Widget _loadingFrame(BuildContext context) {
    final colors = context.colors;
    return ElumSheetFrame(
      child: Semantics(
        // 낭독기가 진행 상황을 바로 읽음
        liveRegion: true,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ElumSpinner(size: _spinnerSize.w, strokeWidth: 3, color: colors.textPrimary),
            SizedBox(height: context.space.sm.h),
            Text(context.l10n.cardSplitLoading, style: context.typo.body.copyWith(color: colors.textPrimary)),
            SizedBox(height: context.space.md.h),
          ],
        ),
      ),
    );
  }

  static const _spinnerSize = 36.0;

  Widget _suggestedFrame(BuildContext context) {
    final l10n = context.l10n;
    final colors = context.colors;
    final space = context.space;
    return ElumSheetFrame(
      title: l10n.cardSplitSheetTitle,
      description: l10n.cardSplitSheetDescription(widget.originalTitle, _drafts.length),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 나눈 카드 목록: 시트 입력칸과 같은 흰 판
          Container(
            padding: EdgeInsets.symmetric(horizontal: space.md.w, vertical: space.md.h),
            decoration: BoxDecoration(
              color: colors.surface,
              borderRadius: BorderRadius.circular(_listRadius.r),
              border: Border.all(color: colors.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (var index = 0; index < _drafts.length; index++) ...[
                  if (index > 0) SizedBox(height: space.sm.h),
                  _SplitDraftRow(order: index + 1, draft: _drafts[index]),
                ],
              ],
            ),
          ),
          SizedBox(height: space.sm.h),
          Text(
            l10n.cardSplitDefaultPictureNote,
            textAlign: TextAlign.center,
            style: context.typo.bodySmall.copyWith(color: colors.textSecondary),
          ),
          SizedBox(height: space.md.h),
          ElumSheetActionRow(
            cancelLabel: l10n.cardSplitKeepButton,
            onCancel: () => Navigator.of(context).pop(),
            confirmLabel: l10n.cardSplitApplyButton,
            onConfirm: _applySuggestion,
            isLoading: _isApplying,
            cancelWidth: _cancelButtonWidth,
          ),
        ],
      ),
    );
  }

  /// 목록 판 모서리 (줄 카드와 같은 20)
  static const _listRadius = 20.0;

  /// `그대로 두기` 가 한 줄에 들어가게 넓힘
  static const _cancelButtonWidth = 120.0;

  Widget _alreadyShortFrame(BuildContext context) => ElumSheetFrame(
    title: context.l10n.cardSplitAlreadyShort,
    description: context.l10n.cardSplitAlreadyShortDescription,
    child: ElumButton(label: context.l10n.commonConfirm, onPressed: () => Navigator.of(context).pop()),
  );

  Widget _failedFrame(BuildContext context) {
    final l10n = context.l10n;
    final failure = _failure ?? const AppFailure(fault: NetworkFault.app);
    return ElumSheetFrame(
      title: failure.bodyOr(l10n.cardSplitFailedFallback),
      description: failure.badgeOr(cardSplitErrorCode),
      child: ElumSheetActionRow(
        cancelLabel: l10n.commonClose,
        onCancel: () => Navigator.of(context).pop(),
        confirmLabel: l10n.cardSplitRetry,
        onConfirm: _retry,
        isLoading: _isApplying,
      ),
    );
  }
}

/// 나눈 카드 한 장: 번호 + 제목(굵게) + 설명(작게)
class _SplitDraftRow extends StatelessWidget {
  const _SplitDraftRow({required this.order, required this.draft});

  final int order;
  final CardSplitDraft draft;

  /// 번호 동그라미 한 변
  static const _numberSize = 24.0;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typo = context.typo;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: _numberSize.w,
          height: _numberSize.w,
          alignment: Alignment.center,
          decoration: BoxDecoration(color: colors.editChipBg, shape: BoxShape.circle),
          child: Text('$order', style: typo.editChipLabel.copyWith(color: colors.textPrimary, fontWeight: FontWeight.w700)),
        ),
        SizedBox(width: context.space.sm.w),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(draft.title, style: typo.editChipLabel.copyWith(color: colors.textPrimary, fontWeight: FontWeight.w700)),
              if (draft.description.isNotEmpty) ...[
                SizedBox(height: 2.h),
                Text(draft.description, style: typo.bodySmall.copyWith(color: colors.textSecondary)),
              ],
            ],
          ),
        ),
      ],
    );
  }
}
