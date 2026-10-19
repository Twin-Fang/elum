import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../theme/theme_context_ext.dart';
import 'twinkle_star_field.dart';

/// 태블릿 장면 그림: 하늘·구름·반짝이·언덕 위에 캐릭터가 선다 (태블릿의 빈 칸을 채우는 장식)
///
/// 캐릭터 그림은 받은 자산 경로 그대로 그린다(루루·포포 전신, 루미 등). 크기는 장면 높이에 맞춰 정해진다.
/// 버튼 그림(테두리 배지)을 장식으로 쓰지 않는다 — 누를 수 있는 것처럼 보인다.
class TabletHeroScene extends StatelessWidget {
  const TabletHeroScene({
    super.key,
    required this.characterAsset,
    this.overlay,
    this.characterHeightRatio = 0.4,
  });

  /// 언덕 위에 세울 그림 (SVG 경로)
  final String characterAsset;

  /// 하늘 위쪽에 얹을 글 (인사말 등). 없으면 장면만
  final Widget? overlay;

  /// 장면 높이 대비 캐릭터 높이
  final double characterHeightRatio;

  /// 장면 모서리 반경 비율 (짧은 변 기준)
  static const _cornerRatio = 0.08;

  /// 언덕 윗선이 시작하는 높이 비율 (아래에서)
  static const _hillTopRatio = 0.3;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = constraints.biggest;
        final characterHeight = size.height * characterHeightRatio;
        final hillTop = size.height * (1 - _hillTopRatio);

        return ClipRRect(
          borderRadius: BorderRadius.circular(size.shortestSide * _cornerRatio),
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [colors.tabletSceneSkyTop, colors.tabletSceneSkyBottom],
              ),
            ),
            child: Stack(
              children: [
                // 하늘 (반짝이 > 구름 > 언덕)
                Positioned.fill(
                  bottom: size.height * _hillTopRatio,
                  child: TwinkleStarField(
                    color: colors.tabletSceneSparkle,
                    starCount: 14,
                    maxRadius: size.shortestSide * 0.012,
                    seed: 11,
                    isFourPointed: true,
                  ),
                ),
                Positioned.fill(
                  child: ExcludeSemantics(
                    child: CustomPaint(
                      painter: _SceneLandscapePainter(
                        cloudColor: colors.tabletSceneCloud,
                        hillBackColor: colors.tabletSceneHillBack,
                        hillFrontColor: colors.tabletSceneHillFront,
                        hillTopRatio: _hillTopRatio,
                      ),
                    ),
                  ),
                ),
                // 발밑 그림자 (언덕 위에 서 있는 느낌)
                Positioned(
                  left: (size.width - characterHeight * 0.7) / 2,
                  top: hillTop - characterHeight * 0.1,
                  width: characterHeight * 0.7,
                  height: characterHeight * 0.14,
                  child: DecoratedBox(
                    decoration: ShapeDecoration(
                      shape: const OvalBorder(),
                      color: colors.tabletSceneGroundShadow,
                    ),
                  ),
                ),
                // 캐릭터: 앞 언덕 꼭대기에 발을 딛는다
                Positioned(
                  left: 0,
                  right: 0,
                  top: hillTop - characterHeight * 0.92,
                  height: characterHeight,
                  child: ExcludeSemantics(
                    child: SvgPicture.asset(
                      characterAsset,
                      height: characterHeight,
                      fit: BoxFit.contain,
                    ),
                  ),
                ),
                if (overlay != null)
                  Positioned(
                    left: size.width * 0.08,
                    right: size.width * 0.08,
                    top: size.height * 0.08,
                    child: overlay!,
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// 구름 3개와 언덕 2겹 (장면 크기 비율로 그려 어떤 칸에도 맞는다)
class _SceneLandscapePainter extends CustomPainter {
  _SceneLandscapePainter({
    required this.cloudColor,
    required this.hillBackColor,
    required this.hillFrontColor,
    required this.hillTopRatio,
  });

  final Color cloudColor;
  final Color hillBackColor;
  final Color hillFrontColor;
  final double hillTopRatio;

  @override
  void paint(Canvas canvas, Size size) {
    final width = size.width;
    final height = size.height;
    final paint = Paint()..isAntiAlias = true;

    // 구름 (왼쪽 위, 오른쪽 가운데, 가운데 낮게)
    paint.color = cloudColor;
    _drawCloud(
      canvas,
      paint,
      Offset(width * 0.18, height * 0.42),
      width * 0.14,
    );
    _drawCloud(
      canvas,
      paint,
      Offset(width * 0.84, height * 0.32),
      width * 0.11,
    );
    _drawCloud(
      canvas,
      paint,
      Offset(width * 0.62, height * 0.55),
      width * 0.08,
    );

    // 뒤 언덕: 오른쪽이 높은 완만한 곡선
    final hillTop = height * (1 - hillTopRatio);
    paint.color = hillBackColor;
    canvas.drawPath(
      Path()
        ..moveTo(0, hillTop + height * 0.06)
        ..quadraticBezierTo(
          width * 0.7,
          hillTop - height * 0.12,
          width,
          hillTop + height * 0.02,
        )
        ..lineTo(width, height)
        ..lineTo(0, height)
        ..close(),
      paint,
    );

    // 앞 언덕: 가운데가 솟아 캐릭터가 선다
    paint.color = hillFrontColor;
    canvas.drawPath(
      Path()
        ..moveTo(0, hillTop + height * 0.14)
        ..quadraticBezierTo(
          width * 0.5,
          hillTop - height * 0.08,
          width,
          hillTop + height * 0.14,
        )
        ..lineTo(width, height)
        ..lineTo(0, height)
        ..close(),
      paint,
    );
  }

  /// 둥근 덩어리 셋을 붙인 구름. [unit] = 구름 폭의 절반
  void _drawCloud(Canvas canvas, Paint paint, Offset center, double unit) {
    canvas
      ..drawCircle(center.translate(-unit * 0.45, 0), unit * 0.42, paint)
      ..drawCircle(center.translate(0, -unit * 0.22), unit * 0.55, paint)
      ..drawCircle(center.translate(unit * 0.5, 0.02 * unit), unit * 0.4, paint)
      ..drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(
            center: center.translate(0, unit * 0.18),
            width: unit * 1.9,
            height: unit * 0.5,
          ),
          Radius.circular(unit * 0.25),
        ),
        paint,
      );
  }

  @override
  bool shouldRepaint(_SceneLandscapePainter oldDelegate) =>
      oldDelegate.cloudColor != cloudColor ||
      oldDelegate.hillBackColor != hillBackColor ||
      oldDelegate.hillFrontColor != hillFrontColor;
}
