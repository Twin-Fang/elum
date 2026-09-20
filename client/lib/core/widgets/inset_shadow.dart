import 'package:flutter/material.dart';

/// CSS `box-shadow: inset ...` 한 줄에 대응하는 값.
///
/// **Flutter의 `BoxDecoration`은 안쪽 그림자를 지원하지 않는다.** 그래서
/// Figma가 `inset`을 쓴 요소를 옮길 때 그 줄만 조용히 빠지기 쉽다 — 실제로
/// `새로운 일과 만들기` 버튼에서 효과 네 줄 중 안쪽 세 줄이 통째로 빠진 채
/// 배포됐고, 디자이너가 화면을 보고서야 드러났다 (이슈 #258).
///
/// 값은 **Figma 덤프의 문자열 순서 그대로** 적는다.
/// `inset 0px -24px 32px 0px rgba(255,255,255,0.24)`는
/// `InsetShadow(offset: Offset(0, -24), blur: 32, color: …)`이다.
class InsetShadow {
  const InsetShadow({
    required this.color,
    this.offset = Offset.zero,
    this.blur = 0,
    this.spread = 0,
  });

  final Color color;
  final Offset offset;

  /// CSS blur-radius. 내부에서 시그마(= blur / 2)로 환산한다.
  final double blur;

  /// 양수면 그림자가 안쪽으로 더 파고들고, 음수면 바깥으로 밀려 거의 안 보인다.
  final double spread;
}

/// [InsetShadow] 목록을 자식 **위에** 그린다.
///
/// ```dart
/// CustomPaint(
///   foregroundPainter: InsetShadowPainter(
///     borderRadius: BorderRadius.circular(100),
///     shadows: const [InsetShadow(color: Colors.white, blur: 10, spread: 2)],
///   ),
///   child: …,
/// )
/// ```
class InsetShadowPainter extends CustomPainter {
  const InsetShadowPainter({
    required this.shadows,
    required this.borderRadius,
  });

  final List<InsetShadow> shadows;
  final BorderRadius borderRadius;

  @override
  void paint(Canvas canvas, Size size) {
    if (shadows.isEmpty) return;
    final bounds = Offset.zero & size;
    final outer = borderRadius.toRRect(bounds);

    for (final shadow in shadows) {
      // CSS는 "요소 안쪽에서 구멍을 뺀 자리"를 칠한다.
      // 구멍은 spread만큼 줄이고 offset만큼 민 모양이다.
      final hole = (shadow.spread >= 0
              ? outer.deflate(shadow.spread)
              : outer.inflate(-shadow.spread))
          .shift(shadow.offset);

      // 색을 가득 칠한 뒤 구멍을 흐리게 뚫는다. 링을 직접 그리면 안쪽 경계가
      // 양방향으로 번져 CSS보다 흐려진다.
      canvas.saveLayer(bounds, Paint());
      canvas.clipRRect(outer);
      canvas.drawRRect(outer, Paint()..color = shadow.color);
      canvas.drawRRect(
        hole,
        Paint()
          ..blendMode = BlendMode.dstOut
          // dstOut은 알파만 쓴다. 디자인 색이 아니라 구멍을 뚫는 마스크다.
          ..color = Colors.black
          ..maskFilter = shadow.blur > 0
              // CSS blur-radius r은 시그마 r/2에 해당한다.
              ? MaskFilter.blur(BlurStyle.normal, shadow.blur / 2)
              : null,
      );
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(InsetShadowPainter oldDelegate) =>
      oldDelegate.shadows != shadows ||
      oldDelegate.borderRadius != borderRadius;
}
