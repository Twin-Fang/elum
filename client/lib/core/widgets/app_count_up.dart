import 'package:flutter/widgets.dart';

import '../theme/app_motion.dart';

/// [from] > [to] 로 세며 바뀌는 숫자 글 (카운트업 시간 · 감속 곡선). 동작 줄이기면 바로 [to]
class AppCountUp extends StatelessWidget {
  const AppCountUp({
    super.key,
    required this.from,
    required this.to,
    required this.format,
    required this.style,
    this.delay = Duration.zero,
  });

  final int from;
  final int to;

  /// 숫자 > 화면 글 (l10n 문구 함수, 예: `+3`)
  final String Function(int value) format;
  final TextStyle style;

  /// 세기 시작을 늦추는 시간 (다른 연출 뒤에 이어 셀 때)
  final Duration delay;

  @override
  Widget build(BuildContext context) {
    if (AppMotion.isReducedMotionOf(context) || from == to) return Text(format(to), style: style);
    final total = delay + AppMotion.countUp;
    // 앞 지연 구간은 from 에 머무름
    final start = delay.inMicroseconds / total.inMicroseconds;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: total,
      builder: (context, progress, _) {
        final eased = Interval(start, 1, curve: AppMotion.decelerate).transform(progress);
        final value = from + (to - from) * eased;
        return Text(format(value.round()), style: style);
      },
    );
  }
}
