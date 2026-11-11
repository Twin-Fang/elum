import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../core/l10n/l10n_context.dart';
import '../../../../core/theme/theme_context_ext.dart';
import '../../../../core/widgets/elum_bottom_sheet.dart';
import '../../../../core/widgets/elum_choice_chip.dart';
import '../../../../core/widgets/elum_sheet_action_row.dart';
import '../../../../core/widgets/elum_sheet_frame.dart';
import '../../../../core/widgets/elum_sheet_text_field.dart';
import '../../../../core/widgets/credit_cost_label.dart';
import '../../../credit/application/image_regenerate_cost.dart';
import '../../domain/image_redraw_hint.dart';

/// 고쳐서 다시 그리기 · AI 그림 그리기 시트: 제목 > 설명 > 고치고 싶은 점(60자) > 칩 4개 > 비용 한 줄 > 취소 · 그리기
///
/// 글·칩은 함께 쓸 수 있고, 둘 다 비면 같은 조건으로 다시 그림. 비용: 다시 그리기는 Pro 무료 횟수 > 크레딧 안 씀 > 크레딧 N개,
/// 처음 그리기는 카드 그림 단가 (무료 횟수 밖). 비용을 못 받으면 `크레딧을 써요` 로 두고 진행은 막지 않음 (서버가 다시 판정)
class CardRegenerateSheet extends ConsumerStatefulWidget {
  const CardRegenerateSheet({super.key, required this.isFirstPicture});

  /// AI 그림이 없던 카드에 처음 그리는가 (제목·버튼·비용이 다름)
  final bool isFirstPicture;

  /// 그리기를 누르면 요청, 취소·내려 닫음이면 null
  static Future<CardRedrawRequest?> show(BuildContext context, {required bool isFirstPicture}) {
    return showElumSheet<CardRedrawRequest>(
      context: context,
      builder: (_) => CardRegenerateSheet(isFirstPicture: isFirstPicture),
    );
  }

  @override
  ConsumerState<CardRegenerateSheet> createState() => _CardRegenerateSheetState();
}

class _CardRegenerateSheetState extends ConsumerState<CardRegenerateSheet> {
  final _requestTextController = TextEditingController();
  final _selectedHints = <ImageRedrawHint>{};

  @override
  void dispose() {
    _requestTextController.dispose();
    super.dispose();
  }

  void _onHintTapped(ImageRedrawHint hint) {
    setState(() {
      if (!_selectedHints.remove(hint)) _selectedHints.add(hint);
    });
  }

  void _onConfirmPressed() {
    Navigator.of(context).pop<CardRedrawRequest>((
      requestText: _requestTextController.text,
      hints: Set.unmodifiable(_selectedHints),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final space = context.space;
    final costAsync = ref.watch(imageRegenerateCostProvider);
    final isFirstPicture = widget.isFirstPicture;

    return ElumSheetFrame(
      title: isFirstPicture ? l10n.cardFirstDrawSheetTitle : l10n.cardRegenerateSheetTitle,
      description: isFirstPicture ? l10n.cardFirstDrawSheetBody : l10n.cardRedrawSheetBody,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ElumSheetTextField(
            controller: _requestTextController,
            label: l10n.cardRedrawRequestLabel,
            hintText: l10n.cardRedrawRequestHint,
            maxLength: ImageRedrawHint.maxRequestTextLength,
            shouldBlockLineBreaks: true,
          ),
          SizedBox(height: space.sm.h),
          Wrap(
            spacing: space.xs.w,
            runSpacing: space.xs.h,
            children: [
              for (final hint in ImageRedrawHint.values)
                ElumChoiceChip(
                  label: _hintLabel(context, hint),
                  isSelected: _selectedHints.contains(hint),
                  onTap: () => _onHintTapped(hint),
                ),
            ],
          ),
          SizedBox(height: space.md.h),
          _costView(context, costAsync.value, isFirstPicture: isFirstPicture),
          SizedBox(height: space.lg.h),
          ElumSheetActionRow(
            cancelLabel: l10n.commonCancel,
            onCancel: () => Navigator.of(context).pop(),
            confirmLabel: isFirstPicture ? l10n.cardFirstDrawConfirm : l10n.cardRegenerateConfirm,
            // 비용을 받는 동안만 잠깐 막음 (실패면 진행 가능)
            onConfirm: costAsync.isLoading ? null : _onConfirmPressed,
            isLoading: costAsync.isLoading,
          ),
        ],
      ),
    );
  }

  static String _hintLabel(BuildContext context, ImageRedrawHint hint) {
    final l10n = context.l10n;
    return switch (hint) {
      ImageRedrawHint.simpler => l10n.cardRedrawHintSimpler,
      ImageRedrawHint.noBackground => l10n.cardRedrawHintNoBackground,
      ImageRedrawHint.noPeople => l10n.cardRedrawHintNoPeople,
      ImageRedrawHint.brighter => l10n.cardRedrawHintBrighter,
    };
  }

  /// 비용 > 한 줄: (다시 그리기만) 무료 횟수 남음 > 크레딧 안 씀 > 크레딧 N개 (모르면 크레딧을 써요)
  /// 비용 한 줄: 크레딧 그림 + 숫자(`1개`) 또는 문구 (낭독은 `크레딧 1개`)
  static Widget _costView(BuildContext context, ImageRegenerateCost? cost, {required bool isFirstPicture}) {
    final l10n = context.l10n;
    final sentence = _costLabel(context, cost, isFirstPicture: isFirstPicture);
    final credits = cost == null ? 0 : (isFirstPicture ? cost.firstPictureCredits : cost.credits);
    final isCountShown = cost != null &&
        (isFirstPicture || cost.freeLeftToday <= 0) &&
        cost.isCreditEnabled &&
        credits > 0;
    return CreditCostLabel(
      text: isCountShown ? l10n.creditCostCount(credits) : sentence,
      semanticLabel: sentence,
    );
  }

  static String _costLabel(BuildContext context, ImageRegenerateCost? cost, {required bool isFirstPicture}) {
    final l10n = context.l10n;
    if (cost == null) return l10n.cardRegenerateCostUnknown;
    if (!isFirstPicture && cost.freeLeftToday > 0) return l10n.cardRegenerateCostProFree(cost.freeLeftToday);
    final credits = isFirstPicture ? cost.firstPictureCredits : cost.credits;
    if (!cost.isCreditEnabled || credits <= 0) return l10n.cardRegenerateCostFree;
    return l10n.cardRegenerateCostCredits(credits);
  }
}
