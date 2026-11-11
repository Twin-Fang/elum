import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../../core/l10n/l10n_context.dart';
import '../../../../core/theme/theme_context_ext.dart';
import '../../../../core/widgets/app_pressable.dart';
import '../../../../core/widgets/settings_switch_tile.dart';
import '../../domain/routine_memory.dart';
import 'routine_memory_labels.dart';

/// 규칙 한 줄 (높이 56 안팎): 종류 아이콘 원 > 글(`{before} → {after}` 에서 before 에 줄, 없으면 summary) + 작은 글 > 스위치(적용 중·꺼짐) 또는 점(관찰 중)
///
/// 줄 전체를 누르면 규칙 시트, 스위치는 따로 눌림
class MemoryRuleRow extends StatelessWidget {
  const MemoryRuleRow({
    super.key,
    required this.rule,
    required this.autoApplyCount,
    required this.onTap,
    required this.onSwitchChanged,
  });

  final MemoryRule rule;
  final int autoApplyCount;
  final VoidCallback onTap;

  /// 스위치를 눌렀을 때 (켜짐 = ACTIVE). 관찰 중 줄은 스위치가 없음
  final ValueChanged<bool> onSwitchChanged;

  static const _circleSize = 36.0;
  static const _iconSize = 18.0;
  static const _minHeight = 56.0;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final space = context.space;
    final l10n = context.l10n;
    final textStyle = context.typo.creditHistoryRowTitle.copyWith(color: colors.textPrimary);
    final isWatching = rule.status == MemoryRuleStatus.watching;
    return AppPressable(
      onTap: onTap,
      child: ConstrainedBox(
        constraints: BoxConstraints(minHeight: _minHeight.h),
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: space.xs.h),
          child: Row(
            children: [
              DecoratedBox(
                decoration: BoxDecoration(color: rule.type.circleColorOf(colors), shape: BoxShape.circle),
                child: SizedBox(
                  width: _circleSize.w,
                  height: _circleSize.w,
                  child: Center(
                    child: SvgPicture.asset(
                      rule.type.iconAsset,
                      width: _iconSize.w,
                      height: _iconSize.w,
                      excludeFromSemantics: true,
                      colorFilter: ColorFilter.mode(colors.surface, BlendMode.srcIn),
                    ),
                  ),
                ),
              ),
              SizedBox(width: space.sm.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _ruleText(rule, textStyle, colors.textSecondary),
                    SizedBox(height: space.xs.h / 2),
                    Text(
                      rule.isManual ? l10n.memoryRuleByMe : l10n.memoryRuleByAi(rule.evidenceCount),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: context.typo.creditCaption.copyWith(color: colors.textSecondary),
                    ),
                  ],
                ),
              ),
              SizedBox(width: space.xs.w),
              if (isWatching)
                _Dots(filled: rule.evidenceCount, total: autoApplyCount)
              else
                AppPressable(
                  onTap: () => onSwitchChanged(rule.status != MemoryRuleStatus.active),
                  child: SettingsToggle(isOn: rule.status == MemoryRuleStatus.active),
                ),
            ],
          ),
        ),
      ),
    );
  }

  /// before 가 있으면 `{before} → {after}` (before 에 줄), 없으면 summary. 한 줄 말줄임
  static Widget _ruleText(MemoryRule rule, TextStyle style, Color mutedColor) {
    if (!rule.hasBeforeAfter) return Text(rule.summary, maxLines: 1, overflow: TextOverflow.ellipsis, style: style);
    return Text.rich(
      TextSpan(
        children: [
          TextSpan(text: rule.before, style: style.copyWith(decoration: TextDecoration.lineThrough, color: mutedColor)),
          TextSpan(text: ' → ${rule.after}'),
        ],
      ),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: style,
    );
  }
}

/// 관찰 점: 본 횟수만큼 채움 (최대 [total] 개)
class _Dots extends StatelessWidget {
  const _Dots({required this.filled, required this.total});

  final int filled;
  final int total;

  static const _size = 8.0;
  static const _gap = 4.0;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final count = total.clamp(1, 10);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var index = 0; index < count; index++) ...[
          if (index > 0) SizedBox(width: _gap.w),
          DecoratedBox(
            decoration: BoxDecoration(
              color: index < filled ? colors.routineMemoryIconWord : colors.buttonNeutral,
              shape: BoxShape.circle,
            ),
            child: SizedBox(width: _size.w, height: _size.w),
          ),
        ],
      ],
    );
  }
}

/// 수정 기록 한 줄: 일과 제목 + `{전}장 → {후}장, 글 {N}곳` (해당 없는 부분은 뺌)
class MemoryEditRow extends StatelessWidget {
  const MemoryEditRow({super.key, required this.edit});

  final MemoryEdit edit;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final l10n = context.l10n;
    final before = edit.cardCountBefore;
    final after = edit.cardCountAfter;
    final textCount = edit.changedTextCount;
    final detail = [
      if (before != null && after != null && before != after) l10n.memoryEditCards(before, after),
      if (textCount != null && textCount > 0) l10n.memoryEditTexts(textCount),
    ].join(', ');
    return Padding(
      padding: EdgeInsets.symmetric(vertical: context.space.sm.h),
      child: Row(
        children: [
          Expanded(
            child: Text(edit.routineTitle, maxLines: 1, overflow: TextOverflow.ellipsis, style: context.typo.creditHistoryRowTitle.copyWith(color: colors.textPrimary)),
          ),
          if (detail.isNotEmpty) ...[
            SizedBox(width: context.space.xs.w),
            Text(detail, style: context.typo.creditCaption.copyWith(color: colors.textSecondary)),
          ],
        ],
      ),
    );
  }
}
