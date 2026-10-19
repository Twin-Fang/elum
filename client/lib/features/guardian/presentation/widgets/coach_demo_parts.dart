import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../core/theme/app_motion.dart';
import '../../../../core/theme/theme_context_ext.dart';
import '../../../../core/widgets/elum_bottom_sheet.dart';

/// 코치마크 시범 연출의 조각들 (손가락·링·시트 미리보기·메뉴 줄·토스트·묶음 모양)과 시간 계산

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

class CoachDemoFinger extends StatelessWidget {
  const CoachDemoFinger({
    super.key,
    required this.center,
    required this.press,
    required this.appear,
  });

  final Offset center;

  /// 0 > 1: 꾹 눌림 (작아짐)
  final double press;

  /// 0 > 1: 나타남 (아래에서 올라오며 짙어짐)
  final double appear;

  @override
  Widget build(BuildContext context) {
    final size = 30.w;
    return Positioned(
      left: center.dx - size / 2,
      top: center.dy - size / 2 + (1 - appear) * 14.h,
      child: Opacity(
        opacity: appear,
        child: Transform.scale(
          scale: 1 - 0.2 * press,
          child: Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              color: context.colors.surface.withValues(alpha: 0.95),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: context.colors.textPrimary.withValues(alpha: 0.35),
                  blurRadius: 8,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class CoachDemoRing extends StatelessWidget {
  const CoachDemoRing({super.key, required this.center, required this.spread});

  final Offset center;

  /// 0 > 1: 퍼지며 옅어짐
  final double spread;

  @override
  Widget build(BuildContext context) {
    final size = 30.w;
    return Positioned(
      left: center.dx - size / 2,
      top: center.dy - size / 2,
      child: Opacity(
        opacity: spread == 0 ? 0 : 1 - spread,
        child: Transform.scale(
          scale: 1 + 1.8 * spread,
          child: Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: context.colors.surface, width: 2),
            ),
          ),
        ),
      ),
    );
  }
}

/// 아래에서 올라오는 시트 미리보기. [slide] 0 = 화면 밖, 1 = 올라옴
class CoachDemoPreviewSheet extends StatelessWidget {
  const CoachDemoPreviewSheet({
    super.key,
    required this.slide,
    required this.child,
  });

  final double slide;
  final Widget child;

  @override
  Widget build(BuildContext context) => Align(
    alignment: Alignment.bottomCenter,
    child: FractionalTranslation(
      translation: Offset(0, 1 - Curves.easeOutCubic.transform(slide)),
      child: ElumSheetSurface(
        child: Padding(
          padding: EdgeInsets.fromLTRB(16.w, 32.h, 16.w, 28.h),
          child: child,
        ),
      ),
    ),
  );
}
