import 'package:flutter/material.dart';

import '../theme/app_motion.dart';

/// 세로 순서 바꾸기 목록의 들린 줄을 가로로도 손가락에 붙임 (기본 목록은 위아래로만 따라옴)
/// 쓰는 법: proxyDecorator > decorate, onReorderStart > start, onReorderEnd > end (놓으면 가로 어긋남 0으로)
class ReorderFingerFollow extends StatefulWidget {
  const ReorderFingerFollow({super.key, required this.builder});

  final Widget Function(BuildContext context, ReorderFingerFollowState follow)
  builder;

  @override
  State<ReorderFingerFollow> createState() => ReorderFingerFollowState();
}

class ReorderFingerFollowState extends State<ReorderFingerFollow>
    with SingleTickerProviderStateMixin {
  /// 들린 줄의 가로 어긋남 (손가락이 끌기 시작점에서 움직인 만큼)
  final _offsetX = ValueNotifier<double>(0);

  /// 놓은 뒤 어긋남을 0으로 되돌리는 움직임 (목록 안착 250ms 안에 끝나게)
  /// initState 에서 만듦 (지연 생성이면 끌지 않고 닫을 때 dispose 안에서 처음 만들어져 TickerMode 조회 assert)
  late final AnimationController _settle;

  /// 첫 손가락만 따라간다 (두 번째 손가락은 무시)
  int? _pointer;
  double _pointerX = 0;
  double _startX = 0;
  double _settleFrom = 0;
  bool _isDragging = false;

  @override
  void initState() {
    super.initState();
    _settle = AnimationController(vsync: this, duration: AppMotion.fast)
      ..addListener(_onSettleTick);
  }

  @override
  void dispose() {
    _settle.dispose();
    _offsetX.dispose();
    super.dispose();
  }

  /// 끌기 시작: 지금 손가락 자리를 기준점으로
  void start() {
    _settle.stop();
    _isDragging = true;
    _startX = _pointerX;
    _offsetX.value = 0;
  }

  /// 놓음: 어긋남을 0으로 되돌린다
  void end() {
    _isDragging = false;
    _settleFrom = _offsetX.value;
    _settle.forward(from: 0);
  }

  /// 목록이 띄운 들린 줄에 가로 어긋남을 입힌다
  Widget decorate(Widget proxy) => ValueListenableBuilder<double>(
    valueListenable: _offsetX,
    builder: (context, offsetX, child) =>
        Transform.translate(offset: Offset(offsetX, 0), child: child),
    child: proxy,
  );

  void _onSettleTick() {
    if (_isDragging) return;
    final eased = Curves.easeOutCubic.transform(_settle.value);
    _offsetX.value = _settleFrom * (1 - eased);
  }

  void _onPointerDown(PointerDownEvent event) {
    if (_pointer != null) return;
    _pointer = event.pointer;
    _pointerX = event.position.dx;
  }

  void _onPointerMove(PointerMoveEvent event) {
    if (event.pointer != _pointer) return;
    _pointerX = event.position.dx;
    if (_isDragging) _offsetX.value = _pointerX - _startX;
  }

  void _onPointerGone(PointerEvent event) {
    if (event.pointer == _pointer) _pointer = null;
  }

  @override
  Widget build(BuildContext context) => Listener(
    onPointerDown: _onPointerDown,
    onPointerMove: _onPointerMove,
    onPointerUp: _onPointerGone,
    onPointerCancel: _onPointerGone,
    child: widget.builder(context, this),
  );
}
