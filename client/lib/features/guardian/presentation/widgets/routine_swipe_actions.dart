import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../../core/assets/app_assets.dart';
import '../../../../core/theme/theme_context_ext.dart';

/// 일과 카드를 왼쪽으로 밀면 나오는 삭제·수정 (Figma 931:4179).
///
/// 카드가 147 비켜나고 그 자리에 삭제(69)·수정(70)이 선다. 두 버튼은 카드와
/// **같은 상자 안** 오른쪽 끝에 붙어 있어, 카드가 비켜난 만큼만 드러난다.
/// 별도 레이어로 띄우지 않는 덕에 목록이 흔들리지 않는다.
///
/// **여는 판단은 부모가 한다.** 목록이 누가 열려 있는지 알아야 다른 것을 열 때
/// 이쪽을 닫을 수 있다 — 둘이 동시에 열리면 어느 버튼이 누구 것인지 알 수 없다.
class RoutineSwipeActions extends StatefulWidget {
  const RoutineSwipeActions({
    super.key,
    required this.child,
    required this.isOpen,
    required this.onOpenChanged,
    required this.onDelete,
    required this.onEdit,
    this.enabled = true,
  });

  final Widget child;

  /// 지금 열려 있어야 하는가. 바뀌면 그 방향으로 미끄러진다.
  final bool isOpen;
  final ValueChanged<bool> onOpenChanged;

  final VoidCallback onDelete;
  final VoidCallback onEdit;

  /// false면 밀리지 않는다. 지난 일과처럼 고칠 수 없는 줄에 쓴다.
  final bool enabled;

  /// Figma 실측 — 삭제 69 · 수정 70 · 사이 4 · 카드와 4
  static const deleteWidth = 69.0;
  static const editWidth = 70.0;
  static const actionGap = 4.0;

  /// 활짝 열렸을 때 카드가 비켜나는 거리 (4 + 69 + 4 + 70).
  static const revealWidth =
      actionGap + deleteWidth + actionGap + editWidth;

  @override
  State<RoutineSwipeActions> createState() => _RoutineSwipeActionsState();
}

class _RoutineSwipeActionsState extends State<RoutineSwipeActions>
    with SingleTickerProviderStateMixin {
  /// 0 = 닫힘, 1 = 활짝 열림. 손가락을 따라갈 때만 이 범위를 벗어난다.
  late final AnimationController _open = AnimationController.unbounded(
    vsync: this,
  );

  /// 지금 미끄러져 가는 목적지. 부모가 같은 방향을 다시 알려올 때
  /// 애니메이션을 처음부터 다시 걸지 않으려고 들고 있는다.
  double? _target;

  /// 튕기지 않고 빠르게 멎는다. iOS 목록의 손맛이 이 감쇠비에서 나온다 —
  /// 조금이라도 출렁이면 버튼 두 개가 같이 흔들려 지저분해 보인다.
  static final _spring = SpringDescription.withDampingRatio(
    mass: 1,
    stiffness: 520,
    ratio: 1.0,
  );

  /// 손가락을 이만큼 세게 튕기면 위치와 상관없이 그 방향으로 간다(진행도/초).
  static const _flingThreshold = 1.2;

  @override
  void initState() {
    super.initState();
    _open.value = widget.isOpen ? 1 : 0;
    _target = _open.value;
  }

  @override
  void didUpdateWidget(covariant RoutineSwipeActions oldWidget) {
    super.didUpdateWidget(oldWidget);
    final wanted = widget.isOpen ? 1.0 : 0.0;
    // 대개는 다른 카드를 열어서 이쪽이 닫히는 경우다.
    if (_target != wanted) _settle(widget.isOpen);
    if (!widget.enabled && _open.value != 0) _settle(false);
  }

  @override
  void dispose() {
    _open.dispose();
    super.dispose();
  }

  double get _reveal => RoutineSwipeActions.revealWidth.w;

  void _settle(bool open, {double velocity = 0}) {
    final target = open ? 1.0 : 0.0;
    _target = target;
    _open
        .animateWith(SpringSimulation(_spring, _open.value, target, velocity))
        .then((_) {
      // 스프링은 허용오차 안에서 멎으므로 끝에 0.0007 같은 찌꺼기가 남는다.
      // 눈에는 안 보이지만 "닫혔는가"를 값으로 판단하는 쪽이 헷갈린다.
      // 중간에 손가락이 다시 닿았으면 _target이 바뀌어 있으므로 건드리지 않는다.
      if (_target == target) _open.value = target;
    });
  }

  /// 끝을 넘긴 만큼을 깎아 점점 뻑뻑하게 만든다. 벽에 닿았다는 것을
  /// 멈춤이 아니라 저항으로 알린다 — 멈춰 세우면 고장 난 것처럼 느껴진다.
  double _rubber(double overflow) => overflow * 0.28;

  void _onDragUpdate(DragUpdateDetails details) {
    final delta = details.primaryDelta;
    if (delta == null) return;
    // 왼쪽으로 미는 것이 여는 방향이라 부호를 뒤집는다.
    var next = _open.value - delta / _reveal;
    if (next < 0) {
      next = _rubber(next);
    } else if (next > 1) {
      next = 1 + _rubber(next - 1);
    }
    _target = null;
    _open.value = next;
  }

  void _onDragEnd(DragEndDetails details) {
    final velocity = -(details.primaryVelocity ?? 0) / _reveal;
    final open = velocity.abs() > _flingThreshold
        // 빠르게 튕겼으면 손가락이 향한 쪽이 뜻이다
        ? velocity > 0
        // 천천히 놓았으면 지금 있는 자리로 판단한다
        : _open.value > 0.5;

    if (open && !widget.isOpen) HapticFeedback.lightImpact();
    _settle(open, velocity: velocity);
    if (open != widget.isOpen) widget.onOpenChanged(open);
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // 뒤에 깔린 동작. 카드가 비켜난 만큼만 보인다.
        Positioned.fill(
          child: AnimatedBuilder(
            animation: _open,
            builder: (context, _) => _ActionRow(
              progress: _open.value.clamp(0.0, 1.0),
              onDelete: widget.onDelete,
              onEdit: widget.onEdit,
            ),
          ),
        ),
        AnimatedBuilder(
          animation: _open,
          builder: (context, child) => Transform.translate(
            offset: Offset(-_open.value * _reveal, 0),
            child: child,
          ),
          child: GestureDetector(
            // 카드 안의 손잡이·버튼이 먼저 잡을 기회를 준다
            behavior: HitTestBehavior.deferToChild,
            onHorizontalDragUpdate: widget.enabled ? _onDragUpdate : null,
            onHorizontalDragEnd: widget.enabled ? _onDragEnd : null,
            child: widget.child,
          ),
        ),
      ],
    );
  }
}

/// 오른쪽 끝에 붙어 있는 삭제·수정 한 쌍.
class _ActionRow extends StatelessWidget {
  const _ActionRow({
    required this.progress,
    required this.onDelete,
    required this.onEdit,
  });

  final double progress;
  final VoidCallback onDelete;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Row(
      // 카드와 같은 높이로 선다
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Spacer(),
        _ActionButton(
          width: RoutineSwipeActions.deleteWidth,
          color: colors.routineSwipeDelete,
          icon: AppAssets.iconTrash,
          label: '일과 삭제',
          onTap: onDelete,
          progress: progress,
        ),
        SizedBox(width: RoutineSwipeActions.actionGap.w),
        _ActionButton(
          width: RoutineSwipeActions.editWidth,
          color: colors.routineSwipeEdit,
          icon: AppAssets.iconPencil,
          label: '일과 수정',
          onTap: onEdit,
          // 수정이 아주 조금 늦게 따라 나온다. 둘이 동시에 뜨면 한 덩어리로 보인다.
          progress: progress,
          iconDelay: 0.12,
        ),
      ],
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.width,
    required this.color,
    required this.icon,
    required this.label,
    required this.onTap,
    required this.progress,
    this.iconDelay = 0,
  });

  final double width;
  final Color color;
  final String icon;

  /// 스크린리더가 읽을 이름. 그림만 있는 버튼이라 없으면 무엇인지 알 수 없다.
  final String label;
  final VoidCallback onTap;
  final double progress;
  final double iconDelay;

  /// Figma 실측 — 아이콘 24×24
  static const _iconSize = 24.0;

  @override
  Widget build(BuildContext context) {
    final space = context.space;
    // 배경은 카드가 비켜나며 드러나고, 그림만 뒤따라 살아난다.
    // 배경까지 같이 커지면 버튼이 튀어나오는 것처럼 보여 과하다.
    final reveal = Interval(iconDelay, 1, curve: Curves.easeOut)
        .transform(progress);

    return Semantics(
      button: true,
      label: label,
      child: GestureDetector(
        onTap: progress > 0.5 ? onTap : null,
        child: Container(
          width: width.w,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(space.cardRadius),
          ),
          alignment: Alignment.center,
          child: Opacity(
            opacity: reveal,
            child: Transform.scale(
              scale: 0.7 + 0.3 * reveal,
              child: SvgPicture.asset(
                icon,
                // 정사각형 아이콘 — 가로세로 모두 .w
                width: _iconSize.w,
                height: _iconSize.w,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
