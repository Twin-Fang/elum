import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import '../../../../core/widgets/app_pressable.dart';

/// 보호자 칸 누름 영역: 누름 상태 · 고른 횟수를 칸 내용에 넘기고, 고를 때 가벼운 진동
///
/// 칸 전체는 줄이지 않는다 — 눌림은 아이콘(`GuardianTabIcon`)만 보여 줘 한 번에 하나만 움직인다
class GuardianTabPressable extends StatefulWidget {
  const GuardianTabPressable({
    super.key,
    required this.onTap,
    required this.builder,
    this.semanticLabel,
  });

  final VoidCallback onTap;

  /// 화면 낭독 이름 (AppPressable.semanticLabel 과 같음)
  final String? semanticLabel;

  /// (누르는 중인가, 고른 횟수) > 칸 내용
  final Widget Function(
    BuildContext context,
    bool isPressed,
    int selectionPlayCount,
  )
  builder;

  @override
  State<GuardianTabPressable> createState() => _GuardianTabPressableState();
}

class _GuardianTabPressableState extends State<GuardianTabPressable> {
  bool _isPressed = false;
  int _selectionPlayCount = 0;

  void _setPressed(bool isPressed) {
    if (_isPressed == isPressed) return;
    setState(() => _isPressed = isPressed);
  }

  /// 고름: 동작 재생 > 진동 > 칸 이동 (이미 고른 칸도 동작은 한 번 더)
  void _onTap() {
    setState(() => _selectionPlayCount++);
    unawaited(HapticFeedback.selectionClick());
    widget.onTap();
  }

  @override
  Widget build(BuildContext context) {
    // 누름 상태는 손가락 기준 — 칸 밖으로 끌어내 떼도 아이콘은 제자리로 돌아온다 (칸은 안 바뀜)
    return Listener(
      onPointerDown: (_) => _setPressed(true),
      onPointerUp: (_) => _setPressed(false),
      onPointerCancel: (_) => _setPressed(false),
      child: AppPressable(
        onTap: _onTap,
        scaleDown: AppPressable.scaleNone,
        semanticLabel: widget.semanticLabel,
        child: widget.builder(context, _isPressed, _selectionPlayCount),
      ),
    );
  }
}
