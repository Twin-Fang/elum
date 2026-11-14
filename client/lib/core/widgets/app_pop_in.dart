import 'package:flutter/widgets.dart';

import '../theme/app_motion.dart';

/// 톡 튀어나오는 등장: 0.7배·투명 > 끝을 살짝 넘었다가 1배 (스프링 곡선)
/// 아이콘·축하 그림·배지처럼 "생겼다"를 알릴 때. 동작 줄이기면 바로 끝 모습
class AppPopIn extends StatefulWidget {
  const AppPopIn({
    super.key,
    required this.child,
    this.delay = Duration.zero,
    this.duration = AppMotion.emphasis,
  });

  final Widget child;

  /// 등장 시작을 늦추는 시간
  final Duration delay;
  final Duration duration;

  @override
  State<AppPopIn> createState() => _AppPopInState();
}

class _AppPopInState extends State<AppPopIn> with SingleTickerProviderStateMixin {
  /// 불투명해지는 구간 (앞 40%, 커지는 동안 이미 또렷)
  static const _opacityEnd = 0.4;

  late final AnimationController _controller;
  late final Animation<double> _scale;
  late final Animation<double> _opacity;

  @override
  void initState() {
    super.initState();
    final total = widget.delay + widget.duration;
    _controller = AnimationController(vsync: this, duration: total);
    // 타임라인 앞 지연 구간은 시작 모습에 머무름 (Timer 없음)
    final start = total == Duration.zero ? 0.0 : widget.delay.inMicroseconds / total.inMicroseconds;
    _scale = Tween(begin: AppMotion.popInStartScale, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Interval(start, 1, curve: AppMotion.springPop)),
    );
    _opacity = CurvedAnimation(
      parent: _controller,
      curve: Interval(start, start + (1 - start) * _opacityEnd),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_controller.isAnimating || _controller.isCompleted) return;
    if (AppMotion.isReducedMotionOf(context)) {
      _controller.value = 1;
      return;
    }
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      child: widget.child,
      // 끝난 뒤에도 같은 모양 유지 (모양이 바뀌면 child 상태가 새로 만들어짐)
      builder: (context, child) {
        return Opacity(
          opacity: _opacity.value.clamp(0.0, 1.0),
          child: Transform.scale(scale: _scale.value, child: child),
        );
      },
    );
  }
}
