import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../theme/theme_context_ext.dart';
import 'app_pressable.dart';
import 'pro_badge.dart';

/// 머리 줄 바로 가기 동그라미: 연한 바탕(단계 줄 색) 지름 40 + 아이콘 20, 누르는 자리 48
///
/// 일과 상세 ↓ 카드 저장하기 · 일과 관리 📅 주간 계획이 같은 모양. Free 에게 권하는 입구면 아래 가장자리에 PRO 배지
class ElumCircleIconButton extends StatelessWidget {
  const ElumCircleIconButton({
    super.key,
    required this.iconAsset,
    required this.semanticLabel,
    required this.onTap,
    this.shouldShowProBadge = false,
  });

  final String iconAsset;

  /// 낭독 이름 (글자가 없는 버튼이라 필수)
  final String semanticLabel;
  final VoidCallback onTap;

  /// Free 라 들어가면 Pro 미리 보기인 입구 (`PlanAccess.shouldShowTeaserFor`)
  final bool shouldShowProBadge;

  /// 동그라미 지름 · 아이콘 한 변 (카드 저장하기 시안 export-button-v2 E)
  static const _circleDiameter = 40.0;
  static const _iconSize = 20.0;

  /// 동그라미 바깥 여백 (누르는 자리 48 확보)
  static const _touchPadding = 4.0;

  /// PRO 배지 튀어나옴 (동그라미 아래 가장자리에 걸침: 가운데 아이콘 20 의 아래 끝 30 밑에서 시작)
  static const _badgeHang = 13.0;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final circle = Container(
      width: _circleDiameter.w,
      height: _circleDiameter.w,
      alignment: Alignment.center,
      // 단계 줄과 같은 바탕색: 시트·화면 바탕보다 한 단계 진해 눌리는 버튼으로 보임
      decoration: BoxDecoration(color: colors.editChipBg, shape: BoxShape.circle),
      child: SvgPicture.asset(
        iconAsset,
        width: _iconSize.w,
        height: _iconSize.w,
        excludeFromSemantics: true,
        colorFilter: ColorFilter.mode(colors.sheetTitleText, BlendMode.srcIn),
      ),
    );
    return AppPressable(
      onTap: onTap,
      scaleDown: AppPressable.scaleIcon,
      semanticLabel: semanticLabel,
      child: Padding(
        padding: EdgeInsets.all(_touchPadding.w),
        child: ProBadgeHang(isShown: shouldShowProBadge, hang: _badgeHang, child: circle),
      ),
    );
  }
}
