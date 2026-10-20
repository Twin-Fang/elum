import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../core/l10n/l10n_context.dart';
import 'arrange_remove_badge.dart';

/// 정리 상태 껍데기: 흔들리고 왼쪽 위에 ⊖ 를 단다. 정리 상태가 아니면 그대로 지나간다
class LibraryArrangeShell extends StatefulWidget {
  const LibraryArrangeShell({
    super.key,
    required this.isArranging,
    required this.isAlternatePhase,
    required this.isRemovable,
    required this.onRemove,
    required this.child,
  });

  final bool isArranging;

  /// 이웃 칸과 어긋나게 흔든다 (시안: 짝수 칸은 반 박자 늦게)
  final bool isAlternatePhase;

  /// ⊖ 를 달 수 있는가 — 남이 만든 일과는 지울 수 없어 달지 않는다 (메뉴가 지우기를 숨기는 것과 같다)
  final bool isRemovable;
  final VoidCallback onRemove;
  final Widget child;

  @override
  State<LibraryArrangeShell> createState() => _LibraryArrangeShellState();
}

class _LibraryArrangeShellState extends State<LibraryArrangeShell>
    with SingleTickerProviderStateMixin {
  /// 흔들림 한 번(왕복의 절반) 시간 · 최대 기울기(도). 홈 화면 편집처럼 빠르게 (왕복 0.26초)
  static const _jiggleHalfPeriod = Duration(milliseconds: 130);
  static const _maxTiltDegrees = 2.4;

  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: _jiggleHalfPeriod);
    if (widget.isArranging) _startJiggle();
  }

  @override
  void didUpdateWidget(LibraryArrangeShell old) {
    super.didUpdateWidget(old);
    if (widget.isArranging == old.isArranging) return;
    if (widget.isArranging) {
      _startJiggle();
    } else {
      _controller
        ..stop()
        ..value = 0;
    }
  }

  void _startJiggle() {
    // 이웃과 어긋나게 시작 위치를 반 박자 옮긴다
    _controller.value = widget.isAlternatePhase ? 0.5 : 0;
    _controller.repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // 정리 상태가 아니어도 같은 모양의 트리를 둔다 — 끄는 중에 상태가 바뀌어도 칸의 제스처가 끊기지 않게
    return Stack(
      clipBehavior: Clip.none,
      children: [
        AnimatedBuilder(
          animation: _controller,
          builder: (context, child) => Transform.rotate(
            angle: widget.isArranging
                ? (_controller.value * 2 - 1) * _maxTiltDegrees * math.pi / 180
                : 0,
            child: child,
          ),
          child: widget.child,
        ),
        if (widget.isArranging && widget.isRemovable)
          Positioned(
            top: -4.h,
            left: 2.w,
            child: ArrangeRemoveBadge(
              onTap: widget.onRemove,
              semanticLabel: context.l10n.libraryArrangeRemove,
            ),
          ),
      ],
    );
  }
}
