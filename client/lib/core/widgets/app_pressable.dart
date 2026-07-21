import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';

/// 눌림 반응 공통 위젯.
///
/// 버튼·카드·아이콘의 터치 피드백을 한 곳에서 통일한다. 위젯마다 제각각이면
/// 같은 앱인데 반응이 달라 보인다. (docs/motion.md)
///
/// **누를 때는 즉시 줄이고, 뗄 때만 물리적으로 복귀한다.**
/// 누르는 순간에도 애니메이션을 걸면 반응이 굼떠 보인다 — 토스가 "즉각 반응"을
/// 강조하는 이유다.
///
/// 접근성 설정에서 동작 줄이기를 켠 사용자에게는 크기 변화를 주지 않는다.
/// 기능은 그대로 동작한다.
class AppPressable extends StatefulWidget {
  const AppPressable({
    super.key,
    required this.child,
    required this.onTap,
    this.onLongPress,
    this.scaleDown = scaleButton,
    this.behavior = HitTestBehavior.opaque,
  });

  final Widget child;

  /// null이면 비활성으로 보고 눌림 반응도 하지 않는다.
  /// 비활성 버튼이 반응하면 눌리는 줄 안다.
  final VoidCallback? onTap;

  final VoidCallback? onLongPress;

  /// 누를 때 줄어드는 비율. 면적이 넓을수록 덜 줄인다.
  final double scaleDown;

  final HitTestBehavior behavior;

  /// 버튼 (CTA·FAB 등 전형적인 버튼)
  static const scaleButton = 0.97;

  /// 카드·리스트 아이템 (면적이 넓어 조금만 줄여도 충분하다)
  static const scaleCard = 0.985;

  /// 아이콘 버튼 (뒤로가기 등 작은 터치 영역)
  static const scaleIcon = 0.93;

  @override
  State<AppPressable> createState() => _AppPressableState();
}

class _AppPressableState extends State<AppPressable>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController.unbounded(
    vsync: this,
    value: 1,
  );

  bool get _isEnabled => widget.onTap != null || widget.onLongPress != null;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onTapDown(TapDownDetails _) {
    if (!_isEnabled || _reduceMotion) return;
    // 애니메이션 없이 즉시 반영한다 — 이게 "즉각 반응"의 핵심이다
    _controller
      ..stop()
      ..value = widget.scaleDown;
  }

  void _releaseWithSpring() {
    if (!_isEnabled || _reduceMotion) return;

    // damping ratio = damping / (2 × √(mass × stiffness)) ≈ 0.65
    // 1.0 미만이라 복귀할 때 살짝 튕긴다.
    const spring = SpringDescription(mass: 1, stiffness: 300, damping: 20);
    _controller.animateWith(
      SpringSimulation(spring, _controller.value, 1, 0),
    );
  }

  /// 접근성 — 동작 줄이기. 움직임이 어지럼증을 유발하는 사용자가 있다.
  bool get _reduceMotion => MediaQuery.disableAnimationsOf(context);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: widget.behavior,
      onTapDown: _onTapDown,
      onTapUp: (_) => _releaseWithSpring(),
      // 밖으로 끌어내 취소해도 원래 크기로 돌아와야 한다
      onTapCancel: _releaseWithSpring,
      onTap: widget.onTap,
      onLongPress: widget.onLongPress,
      child: AnimatedBuilder(
        animation: _controller,
        // child를 밖에서 만들어 스케일이 바뀔 때마다 다시 빌드하지 않는다
        child: widget.child,
        builder: (context, child) => Transform.scale(
          scale: _controller.value,
          child: child,
        ),
      ),
    );
  }
}
