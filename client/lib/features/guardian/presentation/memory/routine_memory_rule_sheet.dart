import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../core/l10n/l10n_context.dart';
import '../../../../core/theme/theme_context_ext.dart';
import '../../../../core/widgets/elum_bottom_sheet.dart';
import '../../../../core/widgets/elum_button.dart';
import '../../../../core/widgets/elum_sheet_frame.dart';
import '../../domain/routine_memory.dart';
import 'routine_memory_labels.dart';

/// 규칙 시트에서 고른 동작
enum MemoryRuleSheetAction { applyNow, edit, delete }

/// 규칙 시트: 종류 이름 > 바꾸기 전후 > 근거 목록(`{일과}, {월}월 {일}일`) > 버튼 (관찰 중 `지금 적용` · 직접 적음 `수정` · `삭제`)
Future<MemoryRuleSheetAction?> showMemoryRuleSheet(BuildContext context, MemoryRule rule) =>
    showElumSheet<MemoryRuleSheetAction>(context: context, builder: (_) => _MemoryRuleSheet(rule: rule));

class _MemoryRuleSheet extends StatelessWidget {
  const _MemoryRuleSheet({required this.rule});

  final MemoryRule rule;

  static const _boxPadding = 12.0;
  static const _maxEvidenceCount = 5;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final space = context.space;
    final l10n = context.l10n;
    final typo = context.typo;
    final primaryAction = switch (rule) {
      MemoryRule(status: MemoryRuleStatus.watching) => (MemoryRuleSheetAction.applyNow, l10n.memoryApplyNow),
      MemoryRule(isManual: true) => (MemoryRuleSheetAction.edit, l10n.memoryRuleEdit),
      _ => null,
    };
    return ElumSheetFrame(
      title: rule.type.typeName(l10n),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          DecoratedBox(
            decoration: BoxDecoration(color: colors.buttonNeutral, borderRadius: BorderRadius.circular(space.sm.r)),
            child: Padding(
              padding: EdgeInsets.all(_boxPadding.w),
              child: rule.hasBeforeAfter
                  ? Text.rich(
                      TextSpan(
                        children: [
                          TextSpan(text: rule.before, style: TextStyle(decoration: TextDecoration.lineThrough, color: colors.textSecondary)),
                          TextSpan(text: ' → ${rule.after}'),
                        ],
                      ),
                      style: typo.creditHistoryRowTitle.copyWith(color: colors.textPrimary),
                    )
                  : Text(rule.summary, style: typo.creditHistoryRowTitle.copyWith(color: colors.textPrimary)),
            ),
          ),
          if (rule.evidences.isNotEmpty) ...[
            SizedBox(height: space.sm.h),
            for (final evidence in rule.evidences.take(_maxEvidenceCount))
              Padding(
                padding: EdgeInsets.only(bottom: space.xs.h / 2),
                child: Text(
                  _evidenceText(l10n, evidence),
                  style: typo.creditBody.copyWith(color: colors.textSecondary),
                ),
              ),
          ],
          SizedBox(height: space.md.h),
          Row(
            children: [
              if (primaryAction != null) ...[
                Expanded(
                  child: ElumButton(label: primaryAction.$2, onPressed: () => Navigator.of(context).pop(primaryAction.$1)),
                ),
                SizedBox(width: space.xs.w),
              ],
              Expanded(
                child: ElumButton(
                  label: l10n.memoryRuleDelete,
                  backgroundColor: colors.dialogNeutral,
                  labelColor: colors.dangerText,
                  onPressed: () => Navigator.of(context).pop(MemoryRuleSheetAction.delete),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  static String _evidenceText(AppLocalizations l10n, MemoryEvidence evidence) {
    final at = evidence.observedAt;
    return at == null ? evidence.routineTitle : l10n.memoryEvidenceLine(evidence.routineTitle, at.month, at.day);
  }
}
