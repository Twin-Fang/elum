import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../theme/app_motion.dart';
import '../theme/theme_context_ext.dart';
import 'app_pressable.dart';

/// 알약 칩 한 개 (시안 1783:6645): 고르면 남색 판 · 흰 글자, 아니면 웜그레이 판
/// 이야기 분류 줄 · 올리기 분류 고르기 · 전문가 일과 분류 줄이 함께 쓴다
class ElumChoiceChip extends StatelessWidget {
  const ElumChoiceChip({
    super.key,
    required this.label,
    required this.isSelected,
    required this.onTap,
    this.isExpanded = false,
    this.labelStyle,
  });

  final String label;
  final bool isSelected;

  /// null 이면 잠긴다 (보내는 중)
  final VoidCallback? onTap;

  /// true 면 받은 폭을 채우고 글자를 가운데에 (격자 · 나란히 두 칸)
  final bool isExpanded;

  /// 글자. null 이면 목록 분류 칩 500/14
  final TextStyle? labelStyle;

  static const _paddingH = 16.0;
  static const _paddingV = 10.0;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final text = Text(
      label,
      textAlign: TextAlign.center,
      style: (labelStyle ?? context.typo.chipLabel).copyWith(
        color: isSelected ? colors.surface : colors.talkTitleText,
      ),
    );
    return Semantics(
      selected: isSelected,
      button: true,
      enabled: onTap != null,
      child: AppPressable(
        onTap: onTap,
        child: AnimatedContainer(
          duration: AppMotion.fast,
          curve: AppMotion.standard,
          width: isExpanded ? double.infinity : null,
          padding: EdgeInsets.symmetric(
            horizontal: _paddingH.w,
            vertical: _paddingV.h,
          ),
          alignment: isExpanded ? Alignment.center : null,
          decoration: BoxDecoration(
            color: isSelected ? colors.textPrimary : colors.editChipBg,
            borderRadius: BorderRadius.circular(context.space.cardRadius.r),
          ),
          child: text,
        ),
      ),
    );
  }
}
