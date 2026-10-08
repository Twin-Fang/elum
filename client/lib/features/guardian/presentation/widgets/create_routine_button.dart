import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../../core/l10n/l10n_context.dart';
import '../../../../core/assets/app_assets.dart';
import '../../../../core/theme/theme_context_ext.dart';
import '../../../../core/widgets/app_pressable.dart';
import '../../../../core/widgets/inset_shadow.dart';

/// `새로운 일과 만들기` (Figma 931:3830 — 361×68, r100).
///
/// 문장 하나짜리 알약이다 — 홈에서 할 일이 이것 하나뿐이라 설명이 필요 없고,
/// 카드 모양이면 아래의 일과 목록과 같은 무게로 읽혀 무엇이 버튼인지 흐려진다.
///
/// **효과가 네 겹이다.** 시안의 `effects` 문자열을 그대로 옮긴 것이며,
/// 안쪽 세 줄이 이 버튼을 "빛나는 알약"으로 보이게 하는 주인공이다.
/// 처음 옮길 때 바깥 한 줄만 구현해 밋밋하게 나갔다.
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

  /// 줄바꿈으로 높이가 늘었을 때 글이 가장자리에 붙지 않게 하는 여백. 기본 크기에서는 최소 높이 안에 들어간다.
  static const _padH = 16.0;
  static const _padV = 12.0;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final radius = BorderRadius.circular(_radius.w);
    final white = colors.surface;

    return AppPressable(
      onTap: onTap,
      scaleDown: AppPressable.scaleCard,
      child: Container(
        // 시안 높이는 최소값이다. 글자가 커져 문구가 줄바꿈되면 늘어난다.
        constraints: BoxConstraints(minHeight: _height.h),
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
                white.withValues(alpha: 0.5),
                white.withValues(alpha: 0),
              ],
            ),
          ),
          child: Padding(
            padding: EdgeInsets.all(_borderWidth.w),
            child: ClipRRect(
              borderRadius: radius,
              child: CustomPaint(
                // 안쪽 그림자 세 겹. BoxDecoration이 inset을 못 받아 직접 그린다.
                foregroundPainter: InsetShadowPainter(
                  borderRadius: radius,
                  shadows: [
                    // inset 0 8px 24px -16px rgba(255,255,255,.24)
                    InsetShadow(
                      color: white.withValues(alpha: 0.24),
                      offset: Offset(0, 8.h),
                      blur: 24.w,
                      spread: -16.w,
                    ),
                    // inset 0 -24px 32px 0 rgba(255,255,255,.24)
                    InsetShadow(
                      color: white.withValues(alpha: 0.24),
                      offset: Offset(0, -24.h),
                      blur: 32.w,
                    ),
                    // inset 0 0 10px 2px rgba(255,255,255,1)
                    // 가장자리를 따라 도는 흰 테두리 — 이 한 줄이 빠지면
                    // 버튼이 그냥 보라색 알약이 된다.
                    InsetShadow(color: white, blur: 10.w, spread: 2.w),
                  ],
                ),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: RadialGradient(
                      center: Alignment.center,
                      radius: _gradientRadius,
                      colors: [
                        colors.routineCreateStart,
                        colors.routineCreateEnd,
                      ],
                    ),
                  ),
                  // heightFactor 1: 높이 제약이 열려 있어도 내용 높이로 서고, 최소 높이는 바깥 상자가 채운다.
                  child: Center(
                    heightFactor: 1,
                    child: Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: _padH.w,
                        vertical: _padV.h,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          SvgPicture.asset(
                            AppAssets.iconSparkles,
                            width: _sparkleW.w,
                            height: _sparkleH.h,
                            // 원본은 홈 카드용 파랑이다. 보라 위에 얹히므로 흰색으로 덮는다.
                            colorFilter: ColorFilter.mode(
                              white,
                              BlendMode.srcIn,
                            ),
                          ),
                          SizedBox(width: _sparkleGap.w),
                          // 글자가 커지면 한 줄에 못 담아 줄바꿈한다 — 잘리는 쪽보다 낫다.
                          Flexible(
                            child: Text(
                              context.l10n.routineCreateButton,
                              style: context.typo.routineCreateLabel.copyWith(
                                color: white,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
