import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';

import '../../../../core/theme/app_motion.dart';
import '../../../../core/widgets/app_pressable.dart';
import 'guardian_tab.dart';
import 'guardian_tab_icon_motion.dart';

/// 보호자 칸 아이콘: 시안 SVG + 눌림(아이콘만 줄며 가라앉음) + 고름 동작 + 색 전환
///
/// 하단 바 · 옆 메뉴가 같이 쓴다. [selectionPlayCount]가 바뀔 때마다 고름 동작 한 번, 동작 줄이기면 색만 바뀜
class GuardianTabIcon extends StatefulWidget {
  const GuardianTabIcon({
    super.key,
    required this.tab,
    required this.size,
    required this.color,
    this.isPressed = false,
    this.selectionPlayCount = 0,
  });

  final GuardianTab tab;

  /// 정사각형 칸 한 변 (화면 배율을 이미 곱한 값)
  final double size;
  final Color color;

  /// 손가락이 칸 위에 닿아 있는가
  final bool isPressed;

  /// 칸을 고른 횟수. 값이 바뀌면 고름 동작을 처음부터 한 번 재생
  final int selectionPlayCount;

  /// 누르는 동안 줄어드는 비율 · 함께 가라앉는 거리 (viewBox 단위)
  static const pressedScale = 0.82;
  static const _pressedSinkUnits = 1.0;

  /// 아이콘 · 칸 이름 · 옆 메뉴 바탕 색 전환 시간 (동작 줄이기면 즉시)
  static Duration colorChangeDurationOf(BuildContext context) =>
      MediaQuery.disableAnimationsOf(context) ? Duration.zero : AppMotion.fast;

  @override
  State<GuardianTabIcon> createState() => _GuardianTabIconState();
}

class _GuardianTabIconState extends State<GuardianTabIcon>
    with TickerProviderStateMixin {
  // 눌림: 1 제자리 ~ pressedScale 눌림 (복귀 스프링이 1을 살짝 넘는다)
  late final AnimationController _pressController =
      AnimationController.unbounded(vsync: this, value: 1);

  // 고름 동작: 1 에서 모든 부위가 제자리라 처음 그릴 때도 1로 둔다
  late final AnimationController _selectionController = AnimationController(
    vsync: this,
    duration: AppMotion.tabIconSelect,
    value: 1,
  );

  late final Listenable _motion = Listenable.merge([
    _pressController,
    _selectionController,
  ]);

  bool get _isReduceMotion => MediaQuery.disableAnimationsOf(context);

  @override
  void didUpdateWidget(GuardianTabIcon oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.isPressed != widget.isPressed) _updatePress();
    if (oldWidget.selectionPlayCount != widget.selectionPlayCount) {
      _playSelection();
    }
  }

  @override
  void dispose() {
    _pressController.dispose();
    _selectionController.dispose();
    super.dispose();
  }

  /// 누름은 즉시 줄이고, 뗄 때만 AppPressable 과 같은 스프링으로 복귀
  void _updatePress() {
    if (_isReduceMotion) return;
    if (widget.isPressed) {
      _pressController
        ..stop()
        ..value = GuardianTabIcon.pressedScale;
      return;
    }
    _pressController.animateWith(
      SpringSimulation(
        AppPressable.releaseSpring,
        _pressController.value,
        1,
        0,
      ),
    );
  }

  /// 진행 중이어도 처음부터 다시 (겹쳐 쌓이지 않음)
  void _playSelection() {
    if (_isReduceMotion) return;
    _selectionController.forward(from: 0);
  }

  @override
  Widget build(BuildContext context) {
    // 눌림 비율만큼 가라앉음 (복귀 스프링이 1을 넘으면 살짝 떠오름)
    final sinkPixelsPerPress =
        GuardianTabIcon._pressedSinkUnits *
        (widget.size / 24) /
        (1 - GuardianTabIcon.pressedScale);
    return RepaintBoundary(
      child: TweenAnimationBuilder<Color?>(
        tween: ColorTween(end: widget.color),
        duration: GuardianTabIcon.colorChangeDurationOf(context),
        builder: (context, color, _) => AnimatedBuilder(
          animation: _motion,
          builder: (context, _) {
            final pressScale = _pressController.value;
            return Transform.translate(
              offset: Offset(0, (1 - pressScale) * sinkPixelsPerPress),
              child: Transform.scale(
                scale: pressScale,
                child: GuardianTabIconMotion(
                  tab: widget.tab,
                  size: widget.size,
                  color: color ?? widget.color,
                  progress: _selectionController.value,
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
