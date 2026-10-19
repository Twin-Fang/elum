import 'package:flutter/widgets.dart';

import 'layout_metrics.dart';

/// 지금 창의 [LayoutMetrics] 를 아래로 내려주는 스코프
///
/// 루트([AdaptiveScreenScale])가 창 크기가 바뀔 때마다 새 값을 넣는다.
class AdaptiveScope extends InheritedWidget {
  const AdaptiveScope({super.key, required this.metrics, required super.child});

  final LayoutMetrics metrics;

  /// 스코프가 없으면 null (테스트 등에서 루트 없이 위젯만 세운 경우)
  static LayoutMetrics? maybeOf(BuildContext context) {
    return context
        .dependOnInheritedWidgetOfExactType<AdaptiveScope>()
        ?.metrics;
  }

  @override
  bool updateShouldNotify(AdaptiveScope oldWidget) {
    return metrics.windowSize != oldWidget.metrics.windowSize;
  }
}
