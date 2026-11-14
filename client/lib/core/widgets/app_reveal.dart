import 'package:flutter/material.dart';

import '../theme/app_motion.dart';

/// 등장 연출 공통 위젯: 투명 > 불투명 + 아래에서 살짝 올라옴 (motion.md 명세)
///
/// 지연 = [delay] + [index] × [AppMotion.staggerStep] (index 상한 [AppMotion.maxStaggerIndex]).
/// 지연은 Timer 가 아니라 컨트롤러 타임라인 앞 구간을 Interval 로 비움 > dispose 뒤 콜백 없음
class AppReveal extends StatefulWidget {
  const AppReveal({
    super.key,
    required this.child,
    this.index = 0,
    this.delay = Duration.zero,
    this.duration = AppMotion.normal,
    this.curve = AppMotion.entry,
    this.offset = AppMotion.revealSlideDistance,
  });

  final Widget child;

  /// 순차 등장 순번 (0부터, 목록·카드 묶음용)
  final int index;

  /// 순번 지연 앞에 더하는 고정 지연 (장면 단위 stagger)
  final Duration delay;
  final Duration duration;
  final Curve curve;

  /// 아래에서 올라오는 거리 (논리 px)
  final double offset;

  @override
  State<AppReveal> createState() => _AppRevealState();
}

class _AppRevealState extends State<AppReveal> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _progress;

  @override
  void initState() {
    super.initState();
    final startDelay = widget.delay + AppMotion.staggerDelayOf(widget.index);
    final total = startDelay + widget.duration;
    _controller = AnimationController(vsync: this, duration: total)..forward();

    // 타임라인 앞 지연 구간은 0에 머무름
    final start = total == Duration.zero ? 0.0 : startDelay.inMicroseconds / total.inMicroseconds;
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
    // 기기 "동작 줄이기" 켜짐 > 움직이지 않고 바로 보임
    if (AppMotion.isReducedMotionOf(context)) return widget.child;
    return AnimatedBuilder(
      animation: _progress,
      builder: (context, child) {
        final value = _progress.value.clamp(0.0, 1.0);
        // 끝난 뒤에도 같은 모양 유지 (불투명 1 은 레이어 없음). 모양이 바뀌면 child 상태가 새로 만들어져 숫자 셈 등이 처음부터 다시 돎
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

/// 목록 > 차례로 떠오르는 목록 (빈 SizedBox 간격은 감싸지 않고 순번도 세지 않음)
List<Widget> revealInOrder(List<Widget> children) {
  var revealIndex = 0;
  return [
    for (final child in children)
      if (child is SizedBox && child.child == null) child else AppReveal(index: revealIndex++, child: child),
  ];
}
