import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../theme/app_motion.dart';
import '../theme/theme_context_ext.dart';

/// 코치마크 말풍선 글을 `*강조*` 표시대로 나눈다 (시안 1274:10400 — 민트 글자).
///
/// 강조가 줄바꿈을 넘어도 이어진다. 시안이 그렇게 그려져 있다
/// (`새로운` 줄과 `일과를 만들 수 있어요` 줄이 한 덩어리로 민트다).
List<TextSpan> coachMessageSpans(
  String message, {
  required TextStyle base,
  required TextStyle accent,
}) {
  final parts = message.split('*');
  return [
    for (final (i, text) in parts.indexed)
      if (text.isNotEmpty) TextSpan(text: text, style: i.isOdd ? accent : base),
  ];
}

/// 화면 낭독기가 읽을 글 — 강조 표시와 줄바꿈을 걷어낸다.
String coachPlainMessage(String message) =>
    message.replaceAll('*', '').replaceAll('\n', ' ');

/// 구멍 하나의 모양. 단계가 바뀔 때 앞 모양에서 뒤 모양으로 미끄러지게 보간한다.
class CoachHole {
  CoachHole({
    required this.rect,
    required this.radius,
    required this.feather,
    this.parts = const [],
    this.partRadius = 0,
  });

  /// 구멍을 감싸는 상자. 화살표·말풍선 자리와 이동 보간의 기준이다.
  final Rect rect;
  final double radius;

  /// 상자 안에서 **실제로 밝아야 하는 모양들**. 비어 있으면 상자 전체가 밝다.
  ///
  /// 밀어서 열린 줄처럼 카드와 버튼 둘이 4 간격으로 나란히 선 것은, 상자 하나로 뚫으면
  /// 버튼 사이 틈과 모서리 바깥이 밝게 새어 나온다. 시안(1291:10401)은 그 틈이 어둡다.
  final List<Rect> parts;
  final double partRadius;

  /// 상자에서 [parts]를 뺀 자리 — 구멍 안인데 다시 어두워야 하는 틈. [parts]가 없으면 null.
  late final Path? gapPath = parts.isEmpty
      ? null
      : Path.combine(
          PathOperation.difference,
          Path()..addRRect(rrect),
          _unionOf(parts, partRadius),
        );

  /// 가장자리를 풀어 주는 정도. 대상이 빛나는 효과(글로우)를 갖고 있으면
  /// 칼같이 오려낼 때 그 빛이 잘려 어둡게 남는다.
  final double feather;

  RRect get rrect => RRect.fromRectAndRadius(rect, Radius.circular(radius));

  static Path _unionOf(List<Rect> rects, double radius) {
    final path = Path();
    for (final r in rects) {
      path.addRRect(RRect.fromRectAndRadius(r, Radius.circular(radius)));
    }
    return path;
  }

  static CoachHole lerp(CoachHole a, CoachHole b, double t) => CoachHole(
    rect: Rect.lerp(a.rect, b.rect, t)!,
    radius: a.radius + (b.radius - a.radius) * t,
    feather: a.feather + (b.feather - a.feather) * t,
  );

  @override
  bool operator ==(Object other) =>
      other is CoachHole &&
      other.rect == rect &&
      other.radius == radius &&
      other.feather == feather;

  @override
  int get hashCode => Object.hash(rect, radius, feather);
}

/// 화면을 어둡게 덮고 [hole] 만 뚫는다.
///
/// 막 위에 구멍을 그리는 대신 **지워서** 뚫는다. 그래야 구멍 안에 아래 화면이
/// 가려지지 않은 채 그대로 보이고, 눌림·그림자도 원래대로 살아 있다.
class CoachScrimPainter extends CustomPainter {
  const CoachScrimPainter({
    required this.color,
    required this.hole,
    this.gaps = const [],
  });

  final Color color;
  final CoachHole? hole;

  /// 구멍 안에서 다시 어둡게 덮을 틈과 그 진하기(0~1). 단계가 바뀔 때 앞 틈은 옅어지고 뒤 틈은 짙어진다.
  final List<({Path path, double alpha})> gaps;

  @override
  void paint(Canvas canvas, Size size) {
    final bounds = Offset.zero & size;
    // 지우기(clear)는 별도 레이어 안에서만 막을 지운다. 레이어 없이 지우면
    // 막 뒤의 화면 전체가 같이 지워진다.
    canvas.saveLayer(bounds, Paint());
    canvas.drawRect(bounds, Paint()..color = color);
    final h = hole;
    if (h != null) {
      final clear = Paint()..blendMode = BlendMode.clear;
      var rrect = h.rrect;
      if (h.feather > 0) {
        clear.maskFilter = MaskFilter.blur(BlurStyle.normal, h.feather / 2);
        // 번지면 가장자리가 반쯤 남으므로, 대상 자체는 완전히 비도록 번진 만큼 키운다.
        rrect = rrect.inflate(h.feather * 0.5);
      }
      canvas.drawRRect(rrect, clear);
      for (final gap in gaps) {
        canvas.drawPath(
          gap.path,
          Paint()..color = color.withValues(alpha: color.a * gap.alpha),
        );
      }
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(CoachScrimPainter old) =>
      old.color != color ||
      old.hole != hole ||
      gaps.isNotEmpty ||
      old.gaps.isNotEmpty;
}

/// 점선 화살표와 글을 구멍 가장자리에 붙여 놓는다 (시안 1274:10397 · 10400).
///
/// 시안의 간격이 모든 단계에서 같다 — 화살표는 구멍 가장자리에서 시작하고,
/// 글은 화살표 끝에서 11 떨어진다. 글의 가로 위치만 단계마다 다르다
/// (가운데 맞춤 / 화살표 오른쪽 13에 끝을 맞춘 오른쪽 맞춤).
class CoachBubbleLayout extends MultiChildLayoutDelegate {
  CoachBubbleLayout({
    required this.anchorX,
    required this.edgeY,
    required this.below,
    required this.alignEnd,
    required this.arrowSize,
    required this.gap,
    required this.margin,
  });

  static const arrowId = 'arrow';
  static const textId = 'text';

  /// 오른쪽 맞춤일 때 글의 오른쪽 끝이 화살표 가운데에서 얼마나 더 나가는가 (시안 실측 13).
  static const endOverhang = 13.0;

  final double anchorX;

  /// 구멍의 아래쪽(`below`) 또는 위쪽 가장자리 y.
  final double edgeY;
  final bool below;
  final bool alignEnd;
  final Size arrowSize;
  final double gap;
  final double margin;

  @override
  void performLayout(Size size) {
    layoutChild(arrowId, BoxConstraints.tight(arrowSize));
    final arrowTop = below ? edgeY : edgeY - arrowSize.height;
    positionChild(arrowId, Offset(anchorX - arrowSize.width / 2, arrowTop));

    final text = layoutChild(
      textId,
      BoxConstraints(maxWidth: math.max(0, size.width - margin * 2)),
    );
    final y = below
        ? arrowTop + arrowSize.height + gap
        : arrowTop - gap - text.height;
    final rawX = alignEnd
        ? anchorX + endOverhang - text.width
        : anchorX - text.width / 2;
    // 글자 크기를 키우거나 대상이 가장자리에 붙어도 글이 화면 밖으로 나가지 않는다.
    final x = rawX
        .clamp(margin, math.max(margin, size.width - margin - text.width))
        .toDouble();
    positionChild(textId, Offset(x, y));
  }

  @override
  bool shouldRelayout(CoachBubbleLayout old) =>
      old.anchorX != anchorX ||
      old.edgeY != edgeY ||
      old.below != below ||
      old.alignEnd != alignEnd ||
      old.arrowSize != arrowSize ||
      old.gap != gap ||
      old.margin != margin;
}

/// 지금 몇 번째 안내인지 알리는 점. 현재 단계만 길쭉하게 늘어난다.
class CoachDots extends StatelessWidget {
  const CoachDots({super.key, required this.count, required this.index});

  final int count;
  final int index;

  static const _dot = 6.0;
  static const _activeWidth = 20.0;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < count; i++)
          AnimatedContainer(
            duration: AppMotion.normal,
            curve: AppMotion.standard,
            margin: EdgeInsets.symmetric(horizontal: 3.w),
            width: (i == index ? _activeWidth : _dot).w,
            height: _dot.w,
            decoration: BoxDecoration(
              color: i == index
                  ? colors.coachAccent
                  : colors.coachText.withValues(alpha: 0.35),
              borderRadius: BorderRadius.circular(_dot.w),
            ),
          ),
      ],
    );
  }
}
