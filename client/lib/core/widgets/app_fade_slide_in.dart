import 'package:flutter/material.dart';

import '../theme/app_motion.dart';

/// 등장 연출 공통 위젯 — opacity 0→1 + 아래에서 살짝 올라온다 (motion.md 명세).
///
/// [delay]로 stagger를 만든다. delay는 Timer가 아니라 **컨트롤러 타임라인의
/// 앞 구간을 Interval로 비우는 방식**이다 — dispose 후 타이머 콜백이 도는
/// 사고가 원천적으로 없다.
class AppFadeSlideIn extends StatefulWidget {
  const AppFadeSlideIn({
    super.key,
    required this.child,
    this.delay = Duration.zero,
    this.duration = AppMotion.normal,
    this.curve = AppMotion.entry,
    this.offset = 16,
  });

  final Widget child;

  /// 등장 시작을 늦추는 시간. stagger용.
  final Duration delay;
  final Duration duration;
  final Curve curve;

  /// 아래에서 올라오는 거리 (논리 px)
  final double offset;

  @override
  State<AppFadeSlideIn> createState() => _AppFadeSlideInState();
}

class _AppFadeSlideInState extends State<AppFadeSlideIn>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _progress;

  @override
  void initState() {
    super.initState();
    final total = widget.delay + widget.duration;
    _controller = AnimationController(vsync: this, duration: total)..forward();

    // 타임라인 앞 delay 구간은 0에 머무른다
    final start = total == Duration.zero
        ? 0.0
        : widget.delay.inMicroseconds / total.inMicroseconds;
    _progress = CurvedAnimation(
      parent: _controller,
      curve: Interval(start, 1, curve: widget.curve),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _progress,
      builder: (context, child) {
        final value = _progress.value;
        // 등장이 끝나면 Opacity·Transform 오버헤드 없이 child만 남긴다
        if (value >= 1) return child!;
        return Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset(0, widget.offset * (1 - value)),
            child: child,
          ),
        );
      },
      child: widget.child,
    );
  }
}
