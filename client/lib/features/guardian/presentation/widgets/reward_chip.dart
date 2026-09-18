import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../core/theme/app_motion.dart';
import '../../../../core/theme/theme_context_ext.dart';
import '../../../../core/widgets/app_pressable.dart';

/// 최근에 쓴 보상 칩 (이슈 #239).
///
/// 배경 그라데이션 위에 얹히므로 **반투명 유리**로 둔다. 불투명한 흰 상자를
/// 올리면 뒤가 잘려 화면이 두 조각으로 보인다.
///
/// 프리셋 칩을 나열하던 것을 걷어냈다 — **보상은 보호자가 자기 말로 적는 것**이지
/// 넷 중에 고르는 것이 아니다. 여기 남은 것은 "전에 쓴 걸 다시 쓰기"뿐이다.
class RewardChip extends StatelessWidget {
  const RewardChip({
    super.key,
    required this.emoji,
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  /// 칩 사이 간격 (가로·세로 공통)
  static const gap = 10.0;

  static const _padV = 10.0;
  static const _padH = 16.0;
  static const _radius = 18.0;
  static const _emojiToLabel = 8.0;

  /// 이모지는 OS 폰트로 그려진다 — 타이포 토큰을 태우지 않는다.
  static const _emojiSize = 18.0;

  /// 유리 흐림 정도. 너무 세면 뒤 색이 죽고, 약하면 글자가 배경에 묻힌다.
  static const _blur = 10.0;

  final String emoji;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return AppPressable(
      onTap: onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(_radius.r),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: _blur, sigmaY: _blur),
          child: AnimatedContainer(
            duration: AppMotion.fast,
            curve: AppMotion.standard,
            padding: EdgeInsets.symmetric(
              vertical: _padV.h,
              horizontal: _padH.w,
            ),
            decoration: BoxDecoration(
              color: isSelected ? colors.goalSelectedFill : colors.glassFill,
              borderRadius: BorderRadius.circular(_radius.r),
              border: Border.all(
                color:
                    isSelected ? colors.goalSelectedBorder : colors.glassBorder,
                width: isSelected
                    ? context.space.selectedBorderWidth
                    : context.space.borderWidth,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(emoji, style: TextStyle(fontSize: _emojiSize.sp)),
                SizedBox(width: _emojiToLabel.w),
                Text(
                  label,
                  style: context.typo.linkRetryChip
                      .copyWith(color: colors.textPrimary),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// 보상을 적는 유리 입력칸 (이슈 #239).
///
/// **이 화면의 주인공이다.** 프리셋에서 고르는 것이 아니라 보호자가 자기 말로
/// 적는다 — `젤리 먹기`처럼 그 집에서만 통하는 말이 진짜 보상이기 때문이다.
class RewardInputField extends StatelessWidget {
  const RewardInputField({
    super.key,
    required this.controller,
    required this.onChanged,
  });

  static const height = 64.0;
  static const _radius = 20.0;
  static const _padH = 20.0;
  static const _blur = 12.0;

  final TextEditingController controller;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return ClipRRect(
      borderRadius: BorderRadius.circular(_radius.r),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: _blur, sigmaY: _blur),
        child: Container(
          height: height.h,
          padding: EdgeInsets.symmetric(horizontal: _padH.w),
          decoration: BoxDecoration(
            color: colors.glassFill,
            borderRadius: BorderRadius.circular(_radius.r),
            border: Border.all(color: colors.glassBorder),
          ),
          alignment: Alignment.center,
          child: TextField(
            controller: controller,
            onChanged: onChanged,
            maxLength: 30,
            textAlignVertical: TextAlignVertical.center,
            style: context.typo.input.copyWith(color: colors.textPrimary),
            decoration: InputDecoration(
              hintText: '예) 젤리 먹기',
              hintStyle:
                  context.typo.input.copyWith(color: colors.textPlaceholder),
              counterText: '',
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
              isDense: true,
              contentPadding: EdgeInsets.zero,
            ),
          ),
        ),
      ),
    );
  }
}
