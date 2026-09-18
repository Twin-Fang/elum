import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/assets/app_assets.dart';
import '../../../../core/router/app_router.dart';
import '../../../../core/theme/theme_context_ext.dart';
import '../../../../core/widgets/app_pressable.dart';
import 'aurora_background.dart';

/// 일과 만들기 흐름의 공통 뼈대.
///
/// 네 화면(입력·로딩·추가질문·카드확인)이 같은 배경과 상단 버튼을 공유한다.
/// 화면마다 반복하면 배경이 조금씩 어긋나고, 무엇보다 [AuroraBackground]가
/// 화면 전환마다 재생성되어 애니메이션이 튄다.
///
/// Figma는 뒤로가기(x=24)와 홈(x=72)을 나란히 둔다. 홈은 흐름을 중간에
/// 빠져나가는 길이다 — 일과 만들기는 단계가 길어 되돌아갈 방법이 필요하다.
class RoutineFlowScaffold extends StatelessWidget {
  const RoutineFlowScaffold({
    super.key,
    required this.child,
    this.onBack,
    this.bottomButton,
    this.showAurora = true,
  });

  final Widget child;

  /// null이면 뒤로가기를 그리지 않는다 (되돌릴 수 없는 단계)
  final VoidCallback? onBack;

  /// 하단 고정 CTA. 입력·로딩 화면에는 없다.
  final Widget? bottomButton;

  /// 배경 글로우를 그릴지. **Figma에 Gradient가 없는 화면은 false로 끈다.**
  ///
  /// 글로우는 입력 화면(238:1643의 Gradient 238:1728)을 재현한 것이라
  /// 모든 화면에 있는 배경이 아니다. 카드확인(262:5124)은 단색 배경뿐이다.
  /// 기본값을 true로 둬 이미 맞는 화면들이 영향받지 않게 한다.
  final bool showAurora;

  @override
  Widget build(BuildContext context) {
    final space = context.space;

    return Scaffold(
      backgroundColor: context.colors.background,
      // 키보드가 올라와도 배경이 밀려 찌그러지지 않게 한다
      resizeToAvoidBottomInset: false,
      body: Stack(
        children: [
          if (showAurora) const Positioned.fill(child: AuroraBackground()),
          SafeArea(
            child: Column(
              children: [
                _TopBar(onBack: onBack),
                Expanded(child: child),
                if (bottomButton != null)
                  Padding(
                    padding: EdgeInsets.fromLTRB(
                      space.buttonMarginH,
                      space.md,
                      space.buttonMarginH,
                      space.lg,
                    ),
                    child: bottomButton,
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// 뒤로가기 + 홈 (Figma x=24 / x=72, y=87)
class _TopBar extends StatelessWidget {
  const _TopBar({this.onBack});

  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(left: context.space.screenH, top: 12.h),
      child: Row(
        children: [
          if (onBack != null)
            AppPressable(
              onTap: onBack,
              scaleDown: AppPressable.scaleIcon,
              // 정사각형 아이콘이라 가로세로 모두 .w
              child: SvgPicture.asset(
                AppAssets.iconBack,
                width: 24.w,
                height: 24.w,
              ),
            )
          else
            SizedBox(width: 24.w),
          SizedBox(width: 24.w),
          AppPressable(
            onTap: () => context.go(Routes.guardian),
            scaleDown: AppPressable.scaleIcon,
            child: SvgPicture.asset(
              AppAssets.iconHome,
              width: 24.w,
              height: 24.w,
            ),
          ),
        ],
      ),
    );
  }
}
