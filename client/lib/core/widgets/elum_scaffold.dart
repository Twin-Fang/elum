import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../assets/app_assets.dart';
import '../theme/theme_context_ext.dart';

/// 온보딩·보호자 화면의 공통 뼈대.
///
/// 배경색 + 좌우 여백 + 상단 리듬 + 하단 CTA 배치를 한 곳에서 관리한다.
/// 화면마다 이 구조를 반복하면 여백이 조금씩 어긋난다.
///
/// ## Figma 좌표를 SafeArea로 옮기는 방법 ⚠️
///
/// Figma 프레임(393×852)은 **StatusBar(y=0~59)와 Home Indicator(y=831~852)를
/// 포함한 전체 화면**이다. 따라서 제목 y=131은 화면 최상단부터 131이지
/// 상태바를 뺀 값이 아니다.
///
/// `SafeArea`는 상태바를 이미 잘라내므로, 그 안에서 Figma y를 그대로 쓰면
/// 상태바 높이(기기별 47~59)만큼 위로 밀린다. 실제로 이 때문에 온보딩 전
/// 화면의 제목이 40px가량 떠 있었다.
///
/// 그래서 `SafeArea`를 쓰지 않고 `MediaQuery.padding`을 직접 읽어
/// `Figma y - safeAreaTop`으로 보정한다. 보정 결과가 음수면 0으로 막는다
/// (노치가 없는 기기·작은 화면에서 겹침 방지).
///
/// 검증된 공통 리듬 — 온보딩 6개 프레임이 전부 동일하다:
/// 뒤로가기 y=75 / 제목 y=131 / 설명 y=211 / 첫 콘텐츠 y=279 / CTA y=675
class ElumScaffold extends StatelessWidget {
  const ElumScaffold({
    super.key,
    required this.child,
    this.bottomButton,
    this.onBack,
    this.horizontalPadding,
  });

  final Widget child;

  /// 하단에 고정되는 CTA. 없으면 영역 자체가 생기지 않는다.
  final Widget? bottomButton;

  /// 뒤로가기. null이면 버튼을 그리지 않는다 (첫 화면).
  final VoidCallback? onBack;

  /// 본문 좌우 여백. 기본은 [AppSpacing.screenH](24).
  ///
  /// 온보딩_캐릭터(204:1029)만 카드가 x=16에서 시작해 16을 넘긴다.
  /// 화면이 직접 Padding을 겹쳐 쓰면 기본 24가 그대로 남아 이중 여백이 된다.
  final double? horizontalPadding;

  /// Figma 뒤로가기 아이콘 좌표 (x=24, y=75, 24×24)
  static const _backIconY = 75.0;
  static const _backIconSize = 24.0;

  /// Figma 프레임 전체 높이. CTA 하단 여백을 화면 하단 기준으로 역산한다.
  ///
  /// CTA는 y=675, h=66 → 하단 741. 프레임 하단 852까지 111이 남는다.
  /// 이 111에서 기기 홈인디케이터(safeBottom)를 빼야 Figma와 같은 위치가 된다.
  /// (Home Indicator 상단 y=831 기준으로 계산하면 21만큼 아래로 밀린다.)
  static const _frameHeight = 852.0;

  @override
  Widget build(BuildContext context) {
    final space = context.space;
    final safeTop = MediaQuery.paddingOf(context).top;
    final safeBottom = MediaQuery.paddingOf(context).bottom;

    // Figma 절대 y를 SafeArea 기준으로 옮긴다. 음수면 0으로 막는다.
    double fromTop(double figmaY) => (figmaY.h - safeTop).clamp(0.0, figmaY.h);

    // CTA 하단 여백 — Figma 버튼 하단(741)에서 프레임 하단(852)까지 111.
    // 여기서 기기 홈인디케이터를 빼야 Figma와 같은 자리에 놓인다.
    final ctaBottom =
        ((_frameHeight - space.ctaTop - space.buttonH).h - safeBottom)
            .clamp(0.0, double.infinity);

    return Scaffold(
      backgroundColor: context.colors.background,
      // SafeArea를 쓰지 않는다 — Figma y가 화면 최상단 기준이라
      // 직접 보정해야 한다 (클래스 주석 참조).
      body: Padding(
        padding: EdgeInsets.only(top: safeTop, bottom: safeBottom),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (onBack != null) ...[
              SizedBox(height: fromTop(_backIconY)),
              Align(
                alignment: Alignment.centerLeft,
                child: Padding(
                  padding: EdgeInsets.only(left: space.screenH.w),
                  // Figma fi-br-angle-left(24×24). Material 아이콘은 형태가 다르다.
                  child: GestureDetector(
                    onTap: onBack,
                    child: SvgPicture.asset(
                      AppAssets.iconBack,
                      width: _backIconSize.w,
                      height: _backIconSize.w,
                    ),
                  ),
                ),
              ),
            ],
            Expanded(
              child: Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: (horizontalPadding ?? space.screenH).w,
                ),
                child: child,
              ),
            ),
            if (bottomButton != null)
              Padding(
                padding: EdgeInsets.fromLTRB(
                  space.buttonMarginH.w,
                  space.md.h,
                  space.buttonMarginH.w,
                  ctaBottom,
                ),
                child: bottomButton,
              ),
          ],
        ),
      ),
    );
  }
}
