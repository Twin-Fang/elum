import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../../core/assets/app_assets.dart';
import '../../../../core/haptics/tap_haptics.dart';
import '../../../../core/l10n/l10n_context.dart';
import '../../../../core/theme/theme_context_ext.dart';
import '../../../../core/widgets/app_pressable.dart';

/// 잠금화면 카드 틀: 위 줄(로고 · 닫기 x) > 가운데 본문 > 아래 버튼 묶음
/// 잠금 엔진 화면과 앱 안 미리 보기가 같은 틀을 씀 (보이는 모습이 같게)
class LockScreenFrame extends StatelessWidget {
  const LockScreenFrame({
    super.key,
    required this.body,
    required this.actions,
    required this.onClose,
  });

  final Widget body;

  /// 아래 버튼 (주 버튼 > 보조 버튼 순서)
  final List<Widget> actions;
  final VoidCallback onClose;

  /// 로고 크기 (보호자 홈 머리 줄과 같음)
  static const _logoWidth = 80.0;
  static const _logoHeight = 30.0;

  /// 닫기 x: 보이는 크기 16, 누름 영역 64 (이룸이도 누르기 쉬운 크기)
  static const _closeIconSize = 16.0;
  static const closeTapSize = 64.0;

  @override
  Widget build(BuildContext context) {
    final space = context.space;
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: space.screenH.w),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(height: space.xs.h),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              SvgPicture.asset(
                AppAssets.homeLogo,
                width: _logoWidth.w,
                height: _logoHeight.h,
              ),
              _closeButton(context),
            ],
          ),
          Expanded(child: Center(child: SingleChildScrollView(child: body))),
          for (final (index, action) in actions.indexed) ...[
            if (index > 0) SizedBox(height: space.xs.h),
            action,
          ],
          SizedBox(height: space.lg.h),
        ],
      ),
    );
  }

  Widget _closeButton(BuildContext context) => AppPressable(
    onTap: withTapHaptic(onClose),
    scaleDown: AppPressable.scaleIcon,
    semanticLabel: context.l10n.commonClose,
    child: SizedBox.square(
      dimension: closeTapSize.w,
      child: Center(
        child: SvgPicture.asset(
          AppAssets.iconClose,
          width: _closeIconSize.w,
          height: _closeIconSize.w,
          excludeFromSemantics: true,
          colorFilter: ColorFilter.mode(
            context.colors.textSecondary,
            BlendMode.srcIn,
          ),
        ),
      ),
    ),
  );
}
