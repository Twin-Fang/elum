import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../core/theme/app_motion.dart';
import '../../../../core/theme/theme_context_ext.dart';

/// 온보딩 기기 고르기 카드 (#1473): 앞 낱말만 색을 달리한 제목 > 설명 한 줄, 고르면 테두리·바탕 강조
/// 역할 선택 카드(RoleCard)와 같은 결. 큰 글자에서 줄어들지 않게 높이는 최소값만 둠
class DeviceUsageChoiceCard extends StatelessWidget {
  const DeviceUsageChoiceCard({
    super.key,
    required this.highlightedWord,
    required this.titleSuffix,
    required this.description,
    required this.highlightColor,
    required this.isSelected,
  });

  final String highlightedWord;
  final String titleSuffix;
  final String description;
  final Color highlightColor;
  final bool isSelected;

  /// 역할 선택 카드와 같은 높이 (Figma 344×96)
  static const _minimumHeight = 96.0;
  static const _horizontalPadding = 24.0;
  static const _titleToDescription = 12.0;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final space = context.space;
    return AnimatedContainer(
      duration: AppMotion.fast,
      curve: AppMotion.standard,
      constraints: BoxConstraints(minHeight: _minimumHeight.h),
      padding: EdgeInsets.symmetric(horizontal: _horizontalPadding.w, vertical: space.md.h),
      decoration: BoxDecoration(
        color: isSelected ? colors.consentSelectedFill : colors.surface,
        borderRadius: BorderRadius.circular(space.cardRadius.r),
        border: Border.all(
          color: isSelected ? colors.consentSelectedBorder : colors.border,
          width: isSelected ? space.selectedBorderWidth : space.borderWidth,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text.rich(
            TextSpan(
              children: [
                TextSpan(text: highlightedWord, style: TextStyle(color: highlightColor)),
                TextSpan(text: titleSuffix),
              ],
            ),
            style: context.typo.subtitle.copyWith(color: colors.chipLabel),
          ),
          SizedBox(height: _titleToDescription.h),
          Text(description, style: context.typo.body.copyWith(color: colors.chipLabel)),
        ],
      ),
    );
  }
}
