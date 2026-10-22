import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../../core/assets/app_assets.dart';
import '../../../../core/theme/app_motion.dart';
import '../../../../core/theme/theme_context_ext.dart';
import '../../../../core/widgets/app_pressable.dart';

/// 오른쪽 표시: 하나만 고르기(동그라미) | 켜고 끄기(네모 체크)
enum TalkChoiceIndicator { radio, check }

/// 고르기 줄: 흰 판 56 · 이름(+ 한 줄 설명) · 오른쪽 동그라미 (신고 사유 · 이룸이 · 묶음 · 규칙 동의)
/// 고르면 연민트 판 + 민트 테두리로 부드럽게 바뀐다. 테두리는 위에 그려 켜고 꺼도 칸 크기가 같다
class TalkChoiceRow extends StatelessWidget {
  const TalkChoiceRow({
    super.key,
    required this.label,
    required this.isSelected,
    required this.onTap,
    this.hint,
    this.indicator = TalkChoiceIndicator.radio,
  });

  final String label;
  final String? hint;
  final bool isSelected;

  /// null 이면 잠긴다 (보내는 중)
  final VoidCallback? onTap;
  final TalkChoiceIndicator indicator;

  /// 줄 최소 높이 · 안쪽 여백 (설정 묶음 줄과 같은 56 · 왼쪽 20 · 오른쪽 16)
  static const _minHeight = 56.0;
  static const _padLeft = 20.0;
  static const _padRight = 16.0;
  static const _padV = 14.0;
  static const _labelToHint = 4.0;
  static const _labelToIndicator = 12.0;

  /// 고른 테두리 두께
  static const _selectedBorderWidth = 1.5;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typo = context.typo;
    final hint = this.hint;
    final radius = BorderRadius.circular(context.space.fieldRadius.r);

    return Semantics(
      selected: indicator == TalkChoiceIndicator.radio ? isSelected : null,
      checked: indicator == TalkChoiceIndicator.check ? isSelected : null,
      button: true,
      enabled: onTap != null,
      child: AppPressable(
        onTap: onTap,
        scaleDown: AppPressable.scaleCard,
        child: AnimatedContainer(
          duration: AppMotion.fast,
          curve: AppMotion.standard,
          constraints: BoxConstraints(minHeight: _minHeight.h),
          padding: EdgeInsets.fromLTRB(
            _padLeft.w,
            _padV.h,
            _padRight.w,
            _padV.h,
          ),
          decoration: BoxDecoration(
            color: isSelected ? colors.talkChoiceSelectedFill : colors.surface,
            borderRadius: radius,
          ),
          foregroundDecoration: BoxDecoration(
            borderRadius: radius,
            border: Border.all(
              color: isSelected
                  ? colors.talkChoiceSelectedBorder
                  : Colors.transparent,
              width: _selectedBorderWidth,
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      label,
                      style: typo.talkChoiceLabel.copyWith(
                        color: colors.textPrimary,
                      ),
                    ),
                    if (hint != null) ...[
                      SizedBox(height: _labelToHint.h),
                      Text(
                        hint,
                        style: typo.talkGuide.copyWith(
                          color: colors.talkMetaText,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              SizedBox(width: _labelToIndicator.w),
              switch (indicator) {
                TalkChoiceIndicator.radio => _RadioMark(isOn: isSelected),
                TalkChoiceIndicator.check => _CheckMark(isOn: isSelected),
              },
            ],
          ),
        ),
      ),
    );
  }
}

/// 동그라미: 빈 원 > 고르면 민트 테두리 안에 짙은 민트 점이 튀어나온다
class _RadioMark extends StatelessWidget {
  const _RadioMark({required this.isOn});

  final bool isOn;

  static const _size = 22.0;
  static const _dotSize = 10.0;
  static const _borderWidth = 1.5;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return AnimatedContainer(
      duration: AppMotion.fast,
      curve: AppMotion.standard,
      width: _size.w,
      height: _size.w,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: colors.surface,
        border: Border.all(
          color: isOn
              ? colors.talkChoiceSelectedBorder
              : colors.talkChoiceRadioBorder,
          width: _borderWidth,
        ),
      ),
      child: AnimatedScale(
        scale: isOn ? 1 : 0,
        duration: AppMotion.normal,
        curve: isOn ? AppMotion.springOut : AppMotion.standard,
        child: Container(
          width: _dotSize.w,
          height: _dotSize.w,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: colors.talkAccentText,
          ),
        ),
      ),
    );
  }
}

/// 네모 체크: 빈 칸 > 켜면 짙은 민트 칸에 흰 체크가 튀어나온다
class _CheckMark extends StatelessWidget {
  const _CheckMark({required this.isOn});

  final bool isOn;

  static const _size = 22.0;
  static const _iconSize = 14.0;
  static const _radius = 6.0;
  static const _borderWidth = 1.5;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return AnimatedContainer(
      duration: AppMotion.fast,
      curve: AppMotion.standard,
      width: _size.w,
      height: _size.w,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: isOn ? colors.talkAccentText : colors.surface,
        borderRadius: BorderRadius.circular(_radius.r),
        border: Border.all(
          color: isOn ? colors.talkAccentText : colors.talkChoiceRadioBorder,
          width: _borderWidth,
        ),
      ),
      child: AnimatedScale(
        scale: isOn ? 1 : 0,
        duration: AppMotion.normal,
        curve: isOn ? AppMotion.springOut : AppMotion.standard,
        child: SvgPicture.asset(
          AppAssets.iconCheckMark,
          width: _iconSize.w,
          height: _iconSize.w,
          colorFilter: ColorFilter.mode(colors.surface, BlendMode.srcIn),
        ),
      ),
    );
  }
}
