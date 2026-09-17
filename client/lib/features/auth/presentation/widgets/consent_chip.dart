import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../core/theme/app_motion.dart';
import '../../../../core/theme/theme_context_ext.dart';
import '../../../../core/widgets/app_pressable.dart';
import '../../domain/consent_documents.dart';

/// 약관 동의 항목 하나.
///
/// **목표 선택 칩(`GoalChip`)과 같은 규격**이다 — Figma `온보딩_목표`(204:1002)의
/// 칩 344×68 r20, 좌측 표시 40×40 @x=38, 텍스트 @x=90. 같은 "여러 개 고르기"인데
/// 생김새가 다르면 같은 흐름 안에서 화면이 갈라져 보인다.
///
/// 다른 점은 **탭 영역이 둘**이라는 것이다. 좌측은 동의 토글, 우측은 전문 열기다.
/// 한 덩어리로 두면 내용을 보려다 동의가 눌리거나 그 반대가 된다.
class ConsentChip extends StatelessWidget {
  const ConsentChip({
    super.key,
    required this.item,
    required this.isChecked,
    required this.onToggle,
    required this.onOpen,
  });

  /// Figma 실측 — 칩 높이 68 고정 (GoalChip과 동일)
  static const height = 68.0;

  /// 좌측 표시와 칩 좌측 사이 여백 (38 - 24). 전체 동의 줄도 이 값에 맞춘다.
  static const markLeft = 14.0;

  /// 좌측 표시와 텍스트 사이 여백 (90 - 38 - 40)
  static const _markToText = 12.0;

  /// 목표 칩의 아이콘 자리를 그대로 쓴다
  static const _markSize = 40.0;

  final ConsentItem item;
  final bool isChecked;
  final VoidCallback onToggle;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final space = context.space;

    return AnimatedContainer(
      // 아동도 볼 수 있는 화면이라 전환을 급하게 두지 않는다 (GoalChip과 동일)
      duration: AppMotion.fast,
      curve: AppMotion.standard,
      height: height.h,
      padding: EdgeInsets.symmetric(horizontal: markLeft.w),
      decoration: BoxDecoration(
        color: isChecked ? colors.consentSelectedFill : colors.surface,
        borderRadius: BorderRadius.circular(space.cardRadius.r),
        border: Border.all(
          color: isChecked ? colors.consentSelectedBorder : colors.border,
          width: isChecked ? space.selectedBorderWidth : space.borderWidth,
        ),
      ),
      child: Row(
        children: [
          AppPressable(
            onTap: onToggle,
            child: SizedBox(
              width: _markSize.w,
              height: _markSize.w,
              child: Center(child: _CheckMark(checked: isChecked)),
            ),
          ),
          SizedBox(width: _markToText.w),
          Expanded(
            child: AppPressable(
              onTap: onOpen,
              child: SizedBox(
                height: double.infinity,
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        item.required ? '[필수] ${item.label}' : '[선택] ${item.label}',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        // Figma 칩 텍스트는 #000000이다. textPrimary가 아니다.
                        style: context.typo.body.copyWith(color: colors.chipLabel),
                      ),
                    ),
                    Icon(
                      Icons.chevron_right,
                      size: space.iconSm.w,
                      color: colors.textSecondary,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 체크 표시. 아동도 보는 화면이라 빨강·경고색을 쓰지 않는다.
class _CheckMark extends StatelessWidget {
  const _CheckMark({required this.checked});

  final bool checked;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final space = context.space;

    return AnimatedContainer(
      duration: AppMotion.fast,
      curve: AppMotion.standard,
      width: space.checkSize.w,
      height: space.checkSize.w,
      decoration: BoxDecoration(
        color: checked ? colors.consentSelectedBorder : Colors.transparent,
        border: Border.all(
          color: checked ? colors.consentSelectedBorder : colors.border,
          width: space.borderWidth,
        ),
        borderRadius: BorderRadius.circular(space.checkRadius.r),
      ),
      child: checked
          ? Icon(Icons.check, size: space.md.w, color: colors.surface)
          : null,
    );
  }
}
