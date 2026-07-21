import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../assets/app_assets.dart';
import '../theme/theme_context_ext.dart';

/// 온보딩·보호자 화면의 공통 뼈대.
///
/// 배경색 + SafeArea + 좌우 24px 여백 + 하단 CTA 배치를 한 곳에서 관리한다.
/// 화면마다 이 구조를 반복하면 여백이 조금씩 어긋난다.
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

  @override
  Widget build(BuildContext context) {
    final space = context.space;

    return Scaffold(
      backgroundColor: context.colors.background,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (onBack != null)
              Align(
                alignment: Alignment.centerLeft,
                // Figma fi-br-angle-left(24×24). Material 아이콘은 형태가 다르다.
                child: IconButton(
                  onPressed: onBack,
                  icon: SvgPicture.asset(
                    AppAssets.iconBack,
                    width: 24,
                    height: 24,
                  ),
                ),
              ),
            Expanded(
              child: Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: horizontalPadding ?? space.screenH,
                ),
                child: child,
              ),
            ),
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
    );
  }
}
