import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../core/theme/theme_context_ext.dart';
import '../../../core/widgets/app_pressable.dart';

/// 제공자 버튼 (360×66 · r18). Figma `로그인`(238:1808) 실측.
///
/// **로고는 왼쪽 64에 고정하고 문구는 버튼 가운데에 둔다.** 로고를 문구 바로
/// 앞에 붙이면 제공자마다 문구 길이가 달라 로고가 들쭉날쭉해진다. 세 개가
/// 한 줄로 서야 목록으로 읽힌다.
class LoginProviderButton extends StatelessWidget {
  const LoginProviderButton({
    super.key,
    required this.label,
    required this.iconAsset,
    required this.backgroundColor,
    required this.labelColor,
    required this.onTap,
  });

  final String label;

  /// 제공자 로고. 색이 SVG 안에 박혀 있어 여기서 덧칠하지 않는다.
  final String iconAsset;

  final Color backgroundColor;
  final Color labelColor;
  final VoidCallback? onTap;

  /// 로고 22×22, 왼쪽에서 64 (시안 실측). 세로는 버튼 가운데다.
  static const _iconSize = 22.0;
  static const _iconLeft = 64.0;

  /// 로고와 문구 사이 최소 간격.
  static const _labelGap = 8.0;

  @override
  Widget build(BuildContext context) {
    final space = context.space;

    return AppPressable(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        height: space.buttonH.h,
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: BorderRadius.circular(space.buttonRadius.r),
          boxShadow: [
            BoxShadow(
              color: context.colors.loginButtonShadow,
              offset: Offset(4.w, 4.h),
              blurRadius: 6.r,
            ),
          ],
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            // 문구는 로고 오른쪽부터 좌우 대칭 여백 안에 둔다. 글꼴 1.0 에서는 문구가 이 폭보다
            // 좁아 버튼 가운데 그대로다. 커지면 로고 쪽으로 자라 붙거나 낱말이 중간에서 끊기는
            // 대신 **한 줄로 폭에 맞춰 줄인다** — 버튼 높이(66)는 시안 그대로 둔다.
            Padding(
              padding: EdgeInsets.symmetric(
                horizontal: (_iconLeft + _iconSize + _labelGap).w,
              ),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  label,
                  maxLines: 1,
                  style: context.typo.loginProvider.copyWith(color: labelColor),
                ),
              ),
            ),
            Positioned(
              left: _iconLeft.w,
              child: SvgPicture.asset(
                iconAsset,
                width: _iconSize.w,
                height: _iconSize.w,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
