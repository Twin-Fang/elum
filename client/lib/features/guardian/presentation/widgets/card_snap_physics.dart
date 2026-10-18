import 'package:flutter/material.dart';

/// 스크롤을 놓으면 가장 가까운 카드가 정면(정중앙)에 붙는 물리.
///
/// 기본 화면의 페이지 뷰와 같은 동작이다. 속도가 있으면 그 방향 다음 카드로 넘어간다.
class CardSnapPhysics extends ScrollPhysics {
  const CardSnapPhysics({required this.itemExtent, super.parent});

  final double itemExtent;

  @override
  CardSnapPhysics applyTo(ScrollPhysics? ancestor) =>
      CardSnapPhysics(itemExtent: itemExtent, parent: buildParent(ancestor));

  double _targetPixels(ScrollMetrics position, double velocity) {
    var page = position.pixels / itemExtent;
    if (velocity < -toleranceFor(position).velocity) {
      page -= 0.5;
    } else if (velocity > toleranceFor(position).velocity) {
      page += 0.5;
    }
    return page.roundToDouble() * itemExtent;
  }

  @override
  Simulation? createBallisticSimulation(
    ScrollMetrics position,
    double velocity,
  ) {
    // 양 끝 밖으로 나가 있으면 기본 물리가 되돌린다
    if ((velocity <= 0.0 && position.pixels <= position.minScrollExtent) ||
        (velocity >= 0.0 && position.pixels >= position.maxScrollExtent)) {
      return super.createBallisticSimulation(position, velocity);
    }
    final target = _targetPixels(
      position,
      velocity,
    ).clamp(position.minScrollExtent, position.maxScrollExtent);
    if (target == position.pixels) return null;
    return ScrollSpringSimulation(
      spring,
      position.pixels,
      target,
      velocity,
      tolerance: toleranceFor(position),
    );
  }

  @override
  bool get allowImplicitScrolling => false;
}
