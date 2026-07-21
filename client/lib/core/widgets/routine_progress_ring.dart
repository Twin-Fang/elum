import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../theme/theme_context_ext.dart';

/// 일과 진행률 링 (Figma 356:4688 / 356:5079 — 40×40, stroke 4).
///
/// 보호자 홈과 아이 홈의 일과 타일이 함께 쓴다.
/// - 진행 중: 트랙(#C9D6D4) 위에 진행분(#55CFBA)을 그리고 가운데 `NN%`
/// - 100%: 링 대신 채워진 체크 원 (Figma Group 36)
class RoutineProgressRing extends StatelessWidget {
  const RoutineProgressRing({super.key, required this.progress});

  /// 0.0 ~ 1.0. 범위 밖 값이 와도 화면이 깨지지 않게 내부에서 자른다.
  final double progress;

  /// Figma 실측 — 링 지름 40, 두께 4
  static const _size = 40.0;
  static const _stroke = 4.0;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final value = progress.clamp(0.0, 1.0);
    final isDone = value >= 1.0;

    // 원형이라 가로세로 모두 .w — 화면비가 달라도 원은 원이어야 한다
    return SizedBox(
      width: _size.w,
      height: _size.w,
      child: isDone
          ? DecoratedBox(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: colors.routineRingProgress,
              ),
              child: Icon(
                Icons.check_rounded,
                size: 22.w,
                color: colors.surface,
              ),
            )
          : CustomPaint(
              painter: _RingPainter(
                progress: value,
                track: colors.routineRingTrack,
                fill: colors.routineRingProgress,
                strokeWidth: _stroke.w,
              ),
              child: Center(
                child: Text(
                  '${(value * 100).round()}%',
                  style: context.typo.ringPercent
                      .copyWith(color: colors.routineRingProgress),
                ),
              ),
            ),
    );
  }
}

/// 트랙 원 + 진행 호. 12시 방향에서 시계 방향으로 채운다.
class _RingPainter extends CustomPainter {
  const _RingPainter({
    required this.progress,
    required this.track,
    required this.fill,
    required this.strokeWidth,
  });

  final double progress;
  final Color track;
  final Color fill;
  final double strokeWidth;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = (size.shortestSide - strokeWidth) / 2;

    final trackPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..color = track;
    canvas.drawCircle(center, radius, trackPaint);

    final fillPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..color = fill;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2,
      2 * math.pi * progress,
      false,
      fillPaint,
    );
  }

  @override
  bool shouldRepaint(_RingPainter oldDelegate) =>
      oldDelegate.progress != progress ||
      oldDelegate.track != track ||
      oldDelegate.fill != fill;
}
