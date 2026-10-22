import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../assets/app_assets.dart';
import '../theme/theme_context_ext.dart';
import 'app_pressable.dart';

/// 칸 아래 가운데 떠 있는 알약 버튼: `+ 새로 만들기` · `+ 올리기` 공통 (시안 1724:7552 · 1783:6640, #964)
/// 자리는 Scaffold 기본 centerFloat (하단 바 위 16)
class ElumFloatingPillButton extends StatelessWidget {
  const ElumFloatingPillButton({
    super.key,
    required this.label,
    required this.onTap,
    this.leading = const ElumFloatingPillPlusIcon(),
  });

  final String label;

  /// null 이면 누르지 못함 (처리 중)
  final VoidCallback? onTap;

  /// 글자 앞 아이콘. null 이면 글자만 (예: 정리 중 `완료`)
  final Widget? leading;

  /// 버튼 높이 · 하단 바와의 간격 (시안 44 · 16)
  static const height = 44.0;
  static const navGap = 16.0;

  /// 목록 끝이 버튼 아래로 숨지 않게 남길 아래 여백 (버튼 + 간격 + 버튼 위 숨 16)
  static const scrollBottomSpace = height + navGap + 16;

  /// 버튼 자리: 가운데 아래, 하단 바 위 [navGap] (= 기본 여백 16)
  static const FloatingActionButtonLocation location =
      FloatingActionButtonLocation.centerFloat;

  /// 아이콘 한 변 · 아이콘과 글자 사이 · 좌우 여백 (시안: 폭 = 30 + 12 + 8 + 글자 + 30)
  static const iconSize = 12.0;
  static const _iconToLabel = 8.0;
  static const _horizontalPadding = 30.0;

  /// 그림자 (#242634 25%, 아래 4, 흐림 20)
  static const _shadowAlpha = 0.25;
  static const _shadowBlur = 20.0;
  static const _shadowOffsetY = 4.0;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final scaledHeight = height.h;
    final leadingWidget = leading;
    return AppPressable(
      onTap: onTap,
      child: Container(
        height: scaledHeight,
        padding: EdgeInsets.symmetric(horizontal: _horizontalPadding.w),
        decoration: BoxDecoration(
          color: colors.buttonEnabled,
          borderRadius: BorderRadius.circular(scaledHeight / 2),
          boxShadow: [
            BoxShadow(
              color: colors.buttonEnabled.withValues(alpha: _shadowAlpha),
              blurRadius: _shadowBlur,
              offset: Offset(0, _shadowOffsetY.h),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (leadingWidget != null) ...[
              leadingWidget,
              SizedBox(width: _iconToLabel.w),
            ],
            Text(
              label,
              style: context.typo.floatingPillLabel.copyWith(
                color: colors.buttonEnabledText,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 알약 버튼 기본 아이콘: 흰 더하기 12
class ElumFloatingPillPlusIcon extends StatelessWidget {
  const ElumFloatingPillPlusIcon({super.key});

  @override
  Widget build(BuildContext context) {
    final iconSize = ElumFloatingPillButton.iconSize.w;
    return SvgPicture.asset(
      AppAssets.iconPlus,
      width: iconSize,
      height: iconSize,
      colorFilter: ColorFilter.mode(
        context.colors.buttonEnabledText,
        BlendMode.srcIn,
      ),
    );
  }
}
