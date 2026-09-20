import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../../core/assets/app_assets.dart';
import '../../../../core/theme/theme_context_ext.dart';
import '../../../../core/widgets/app_pressable.dart';

/// `새로운 일과 만들기` (Figma 931:3830 — 361×68, r100).
///
/// 개편 전에는 병아리 그림과 설명 두 줄이 붙은 94 높이 카드였다. 지금은
/// 문장 하나짜리 알약이다 — 홈에서 할 일이 이것 하나뿐이라 설명이 필요 없고,
/// 카드 모양이면 아래의 일과 목록과 같은 무게로 읽혀 무엇이 버튼인지 흐려진다.
class CreateRoutineButton extends StatelessWidget {
  const CreateRoutineButton({super.key, required this.onTap});

  final VoidCallback onTap;

  static const _height = 68.0;
  static const _radius = 100.0;

  /// 테두리는 1px 그라데이션이다. 위 왼쪽이 희고 아래 오른쪽으로 사라진다.
  static const _borderWidth = 1.0;

  /// 바깥으로 번지는 빛 — 그림자가 아니라 발광이라 색이 진하고 흐림이 크다.
  static const _glowBlur = 20.0;
  static const _glowDy = 4.0;

  /// 방사형 그라데이션이 상자의 먼 모서리까지 닿는 반지름.
  /// Flutter는 짧은 변 기준이라 `대각선 절반 ÷ 높이`로 환산한다.
  static const _gradientRadius = 2.7;

  static const _sparkleW = 15.0;
  static const _sparkleH = 18.0;
  static const _sparkleGap = 6.0;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final radius = BorderRadius.circular(_radius.w);

    return AppPressable(
      onTap: onTap,
      scaleDown: AppPressable.scaleCard,
      child: Container(
        height: _height.h,
        decoration: BoxDecoration(
          borderRadius: radius,
          boxShadow: [
            BoxShadow(
              color: colors.routineCreateGlow,
              blurRadius: _glowBlur.w,
              offset: Offset(0, _glowDy.h),
            ),
          ],
        ),
        // 바깥 상자가 테두리색을 깔고, 1 안쪽에 본체가 얹힌다.
        // Flutter의 Border는 그라데이션을 받지 못해 이렇게 두 겹으로 만든다.
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: radius,
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                colors.surface.withValues(alpha: 0.5),
                colors.surface.withValues(alpha: 0),
              ],
            ),
          ),
          child: Padding(
            padding: EdgeInsets.all(_borderWidth.w),
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: radius,
                gradient: RadialGradient(
                  center: Alignment.center,
                  radius: _gradientRadius,
                  colors: [
                    colors.routineCreateStart,
                    colors.routineCreateEnd,
                  ],
                ),
              ),
              child: Center(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SvgPicture.asset(
                      AppAssets.iconSparkles,
                      width: _sparkleW.w,
                      height: _sparkleH.h,
                      // 원본은 홈 카드용 파랑이다. 보라 위에 얹히므로 흰색으로 덮는다.
                      colorFilter: ColorFilter.mode(
                        colors.surface,
                        BlendMode.srcIn,
                      ),
                    ),
                    SizedBox(width: _sparkleGap.w),
                    Text(
                      '새로운 일과 만들기',
                      style: context.typo.routineCreateLabel
                          .copyWith(color: colors.surface),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
