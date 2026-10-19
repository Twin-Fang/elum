import 'dart:math' as math;

import 'package:flutter/material.dart';

/// 정해진 자리에서 천천히 반짝이는 별 밭 (밤하늘 배경·장면 그림 공용)
///
/// 자리는 [seed] 로 고정 — 다시 그려도 별이 튀지 않는다. 동작 줄이기면 반짝임 없이 그대로 둔다.
class TwinkleStarField extends StatefulWidget {
  const TwinkleStarField({
    super.key,
    required this.color,
    this.starCount = 40,
    this.maxRadius = 2.4,
    this.seed = 7,
    this.isFourPointed = false,
  });

  final Color color;
  final int starCount;

  /// 가장 큰 별 반지름 (px)
  final double maxRadius;
  final int seed;

  /// 네 갈래 반짝이 모양으로 그릴지 (밝은 장면용). false 면 둥근 점
  final bool isFourPointed;

  /// 반짝임 한 바퀴 (별마다 위상이 달라 함께 깜빡이지 않는다)
  static const twinklePeriod = Duration(seconds: 5);

  @override
  State<TwinkleStarField> createState() => _TwinkleStarFieldState();
}

class _TwinkleStarFieldState extends State<TwinkleStarField>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: TwinkleStarField.twinklePeriod,
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // 접근성 설정은 실행 중에도 바뀐다
    final shouldAnimate = !MediaQuery.disableAnimationsOf(context);
    if (shouldAnimate && !_controller.isAnimating) {
      _controller.repeat();
    } else if (!shouldAnimate && _controller.isAnimating) {
      _controller
        ..stop()
        ..value = 0;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // 장식이라 낭독기에 내놓지 않고, 위에 얹힌 화면만 다시 그리지 않게 격리한다
    return ExcludeSemantics(
      child: RepaintBoundary(
        child: CustomPaint(
          size: Size.infinite,
          painter: _StarFieldPainter(
            animation: _controller,
            color: widget.color,
            stars: _StarSpec.scatter(widget.starCount, widget.seed),
            maxRadius: widget.maxRadius,
            isFourPointed: widget.isFourPointed,
          ),
        ),
      ),
    );
  }
}

/// 별 하나: 자리(0~1 비율), 크기 비율, 위상
@immutable
class _StarSpec {
  const _StarSpec(this.position, this.sizeRatio, this.phase);

  final Offset position;
  final double sizeRatio;
  final double phase;

  static List<_StarSpec> scatter(int count, int seed) {
    final random = math.Random(seed);
    return [
      for (var index = 0; index < count; index++)
        _StarSpec(
          Offset(random.nextDouble(), random.nextDouble()),
          0.35 + random.nextDouble() * 0.65,
          random.nextDouble(),
        ),
    ];
  }
}

class _StarFieldPainter extends CustomPainter {
  _StarFieldPainter({
    required this.animation,
    required this.color,
    required this.stars,
    required this.maxRadius,
    required this.isFourPointed,
  }) : super(repaint: animation);

  final Animation<double> animation;
  final Color color;
  final List<_StarSpec> stars;
  final double maxRadius;
  final bool isFourPointed;

  /// 가장 어두울 때 불투명도 (완전히 사라지면 별이 없어진 것처럼 보인다)
  static const _minimumOpacity = 0.35;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..isAntiAlias = true;
    for (final star in stars) {
      // 별마다 위상을 달리한 사인파 > 불투명도
      final wave = math.sin((animation.value + star.phase) * 2 * math.pi);
      final opacity = _minimumOpacity + (1 - _minimumOpacity) * (wave + 1) / 2;
      paint.color = color.withValues(alpha: color.a * opacity);
      final center = Offset(
        star.position.dx * size.width,
        star.position.dy * size.height,
      );
      final radius = maxRadius * star.sizeRatio;
      if (isFourPointed) {
        canvas.drawPath(_fourPointedStar(center, radius * 2.2), paint);
      } else {
        canvas.drawCircle(center, radius, paint);
      }
    }
  }

  /// 네 갈래 반짝이 (안쪽으로 오목한 마름모)
  Path _fourPointedStar(Offset center, double radius) {
    final inner = radius * 0.28;
    return Path()
      ..moveTo(center.dx, center.dy - radius)
      ..quadraticBezierTo(
        center.dx + inner,
        center.dy - inner,
        center.dx + radius,
        center.dy,
      )
      ..quadraticBezierTo(
        center.dx + inner,
        center.dy + inner,
        center.dx,
        center.dy + radius,
      )
      ..quadraticBezierTo(
        center.dx - inner,
        center.dy + inner,
        center.dx - radius,
        center.dy,
      )
      ..quadraticBezierTo(
        center.dx - inner,
        center.dy - inner,
        center.dx,
        center.dy - radius,
      )
      ..close();
  }

  @override
  bool shouldRepaint(_StarFieldPainter oldDelegate) =>
      oldDelegate.color != color ||
      oldDelegate.maxRadius != maxRadius ||
      oldDelegate.isFourPointed != isFourPointed ||
      oldDelegate.stars.length != stars.length;
}
