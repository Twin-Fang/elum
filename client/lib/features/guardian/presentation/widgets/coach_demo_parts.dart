import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../core/theme/app_motion.dart';
import '../../../../core/theme/theme_context_ext.dart';

/// 코치마크 시범 연출의 조각들 (대상 모양 누름 표시)과 시간 계산

/// 한 주기를 도는 시범. 동작 줄이기면 [endScene] 지점의 멈춘 장면만 그린다.
Widget buildCoachDemoLoop({
  required double endScene,
  required Widget Function(BuildContext context, double t) builder,
}) => Positioned.fill(
  child: CoachDemoLoop(endScene: endScene, builder: builder),
);

class CoachDemoLoop extends StatefulWidget {
  const CoachDemoLoop({
    super.key,
    required this.endScene,
    required this.builder,
  });

  final double endScene;
  final Widget Function(BuildContext context, double t) builder;

  @override
  State<CoachDemoLoop> createState() => _CoachDemoLoopState();
}

class _CoachDemoLoopState extends State<CoachDemoLoop>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: AppMotion.coachDemoLoop,
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _controller.stop();
    } else if (!_controller.isAnimating) {
      _controller.repeat();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.disableAnimationsOf(context)) {
      return widget.builder(context, widget.endScene);
    }
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) => widget.builder(context, _controller.value),
    );
  }
}

/// 주기 t 안에서 [begin, end] 구간의 진행도 0~1
double coachDemoPhase(double t, double begin, double end) =>
    ((t - begin) / (end - begin)).clamp(0.0, 1.0);

/// [begin, end] 구간에서 0 > 1 > 0 으로 오가는 값 (눌렀다 뗌)
double coachDemoPulse(double t, double begin, double end) {
  final progress = coachDemoPhase(t, begin, end);
  return progress < 0.5 ? progress * 2 : (1 - progress) * 2;
}

// --- 조각 ---

/// 누름 표시: 대상과 **같은 모양**(둥근 사각, 반지름 그대로)으로 밝아졌다가 바깥으로 번짐
///
/// 동그라미 손가락을 대상 모서리에 얹으면 사각 버튼과 모양이 어긋나고 이름을 덮는다.
/// 테두리만 그려 대상 그림·이름을 가리지 않고, 번짐은 화면 끝에서 잘리지 않을 만큼만 넓힌다.
class CoachDemoPressOutline extends StatelessWidget {
  const CoachDemoPressOutline({
    super.key,
    required this.rect,
    required this.radius,
    required this.press,
    this.ripple = 0,
  });

  final Rect rect;
  final double radius;

  /// 0 > 1: 눌림 (테두리가 짙어지고 안이 옅게 밝아짐)
  final double press;

  /// 0 > 1: 같은 모양이 바깥으로 번지며 옅어짐 (0·1 은 안 그림)
  final double ripple;

  /// 테두리 두께 · 눌림 때 안쪽 밝기 · 번짐 최대 폭
  static const _strokeWidth = 2.0;
  static const _pressFillAlpha = 0.18;
  static const _rippleSpread = 10.0;

  @override
  Widget build(BuildContext context) {
    final surface = context.colors.surface;
    final stroke = _strokeWidth.w;
    final spread = _rippleSpreadWithin(MediaQuery.sizeOf(context)) * ripple;
    return Stack(
      children: [
        if (press > 0)
          Positioned.fromRect(
            rect: rect,
            child: Opacity(
              opacity: press,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: surface.withValues(alpha: _pressFillAlpha),
                  borderRadius: BorderRadius.circular(radius),
                  border: Border.all(color: surface, width: stroke),
                ),
              ),
            ),
          ),
        if (ripple > 0 && ripple < 1)
          Positioned.fromRect(
            rect: rect.inflate(spread),
            child: Opacity(
              opacity: 1 - ripple,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(radius + spread),
                  border: Border.all(color: surface, width: stroke),
                ),
              ),
            ),
          ),
      ],
    );
  }

  /// 번짐 최대 폭: 화면 네 끝까지 남은 거리를 넘지 않게 (끝에 붙은 대상은 번지지 않음)
  double _rippleSpreadWithin(Size screen) {
    final room = [
      rect.left,
      rect.top,
      screen.width - rect.right,
      screen.height - rect.bottom,
    ].reduce((a, b) => a < b ? a : b);
    return room.clamp(0.0, _rippleSpread.w);
  }
}
