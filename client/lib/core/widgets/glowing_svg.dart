import 'dart:ui' as ui;

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
///
/// 큰 별은 여기에 더해 Figma에 **별 모양대로 넓게 번지는 blur(20px) 후광**
/// 레이어가 따로 있다(node 364:8283 / 334:4282). `RadialGradient`만으로는
/// 이 후광이 약해서 [haloBlur]로 별 SVG를 한 겹 더 흐리게 깔아 재현한다.
/// 기본값 0이라 후광이 필요 없는 작은 별은 기존과 동일하게 그려진다 (이슈 #107).
class GlowingSvg extends StatelessWidget {
  const GlowingSvg({
    super.key,
    required this.assetPath,
    required this.size,
    required this.glowColor,
    this.haloBlur = 0,
    this.haloColor,
  });

  final String assetPath;
  final double size;
  final Color glowColor;

  /// 별 모양 후광의 흐림 정도(sigma). 0이면 후광을 그리지 않는다.
  ///
  /// Figma는 blur(20px)이지만 Flutter의 sigma는 스케일이 달라 값을 그대로
  /// 쓰지 않는다. 시뮬레이터에서 PNG와 대조해 맞춘 값을 넘긴다.
  final double haloBlur;

  /// 후광 색. 비우면 [glowColor]를 쓴다 — 큰 별은 노란 후광이라 별도 지정한다.
  final Color? haloColor;

  @override
  Widget build(BuildContext context) {
    final glow = DecoratedBox(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [glowColor, glowColor.withValues(alpha: 0)],
        ),
      ),
      child: SvgPicture.asset(assetPath, width: size, height: size),
    );

    // 후광이 꺼져 있으면(작은 별 등) 기존 렌더 그대로 둔다.
    if (haloBlur <= 0) return glow;

    // 별 SVG를 색으로 덮어(srcATop) 흐리게 깐 뒤, 그 위에 실제 별을 얹는다.
    // 후광이 별 크기를 넘어 번지도록 clip하지 않는다.
    return Stack(
      alignment: Alignment.center,
      clipBehavior: Clip.none,
      children: [
        ImageFiltered(
          imageFilter: ui.ImageFilter.blur(sigmaX: haloBlur, sigmaY: haloBlur),
          child: SvgPicture.asset(
            assetPath,
            width: size,
            height: size,
            colorFilter: ColorFilter.mode(
              haloColor ?? glowColor,
              BlendMode.srcATop,
            ),
          ),
        ),
        glow,
      ],
    );
  }
}
