import 'package:flutter/widgets.dart';

import '../theme/app_motion.dart';

/// 0 > [value] 로 차오르는 비율 (링·도넛·막대): 처음엔 0부터, 값이 바뀌면 이전 값에서 이어 감
/// 카운트업과 같은 호흡 · 감속 곡선. 동작 줄이기면 바로 끝 값
class AppAnimatedFraction extends StatelessWidget {
  const AppAnimatedFraction({
    super.key,
    required this.value,
    required this.builder,
    this.delay = Duration.zero,
  });

  /// 목표 비율 (0.0 ~ 1.0, 범위 밖은 자름)
  final double value;

  /// 지금 비율 > 그림
  final Widget Function(BuildContext context, double fraction) builder;

  /// 차오르기 시작을 늦추는 시간 (막대 여러 개를 차례로)
  final Duration delay;

  @override
  Widget build(BuildContext context) {
    final target = value.clamp(0.0, 1.0);
    if (AppMotion.isReducedMotionOf(context)) return builder(context, target);
    final total = delay + AppMotion.countUp;
    // 앞 지연 구간은 시작 값에 머무름
    final start = delay.inMicroseconds / total.inMicroseconds;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: target),
      duration: total,
      curve: Interval(start, 1, curve: AppMotion.decelerate),
      builder: (context, fraction, _) => builder(context, fraction),
    );
  }
}
