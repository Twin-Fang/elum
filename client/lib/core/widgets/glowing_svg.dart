import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// 뒤에서 은은히 번지는 빛과 함께 SVG를 그린다.
///
/// Figma는 이 빛을 `boxShadow`(별 화면) 또는 SVG 내장 `feGaussianBlur`
/// 필터(별 모으기 화면의 star_deco_*.svg)로 표현하는데, **둘 다
/// flutter_svg가 그려내지 못한다.** 필터는 SVG 렌더러가 무시하고,
/// boxShadow는 채워진 도형 뒤에 같은 모양을 그대로 칠해 불투명한
/// 원판이 된다 — 그래서 가장자리로 갈수록 투명해지는 `RadialGradient`로
/// 재현한다. (client/CLAUDE.md §2, docs/troubleshooting.md)
class GlowingSvg extends StatelessWidget {
  const GlowingSvg({
    super.key,
    required this.assetPath,
    required this.size,
    required this.glowColor,
  });

  final String assetPath;
  final double size;
  final Color glowColor;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [glowColor, glowColor.withValues(alpha: 0)],
        ),
      ),
      child: SvgPicture.asset(assetPath, width: size, height: size),
    );
  }
}
