import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import 'guardian_tab.dart';

/// 보호자 칸 아이콘: 시안 SVG 한 장 + 색 입히기 (#835)
///
/// 하단 바 · 옆 메뉴 · 준비 중 화면이 같이 쓴다. 폭 · 높이가 다른 SVG(폴더 24×22 · 사람 16×24)는 정사각형 칸 가운데에 비율 그대로 둔다.
class GuardianTabIcon extends StatelessWidget {
  const GuardianTabIcon({
    super.key,
    required this.tab,
    required this.size,
    required this.color,
  });

  final GuardianTab tab;

  /// 정사각형 칸 한 변 (화면 배율을 이미 곱한 값)
  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: size,
      child: SvgPicture.asset(
        tab.iconAsset,
        colorFilter: ColorFilter.mode(color, BlendMode.srcIn),
      ),
    );
  }
}
