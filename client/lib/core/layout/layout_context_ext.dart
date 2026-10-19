import 'package:flutter/material.dart';

import 'adaptive_scope.dart';
import 'app_layout.dart';
import 'layout_metrics.dart';
import 'window_size_class.dart';

/// 레이아웃 정보 접근을 짧게 유지하는 확장 (`context.layout`, `context.sizeClass`)
///
/// 화면 코드는 창 폭 숫자를 비교하지 않고 이 확장만 쓴다.
extension LayoutContextExt on BuildContext {
  /// 레이아웃 토큰. 테마에 없으면 표준값
  AppLayout get layout =>
      Theme.of(this).extension<AppLayout>() ?? AppLayout.standard;

  /// 지금 창의 등급·방향·배율. 루트 스코프가 없으면 MediaQuery 로 계산
  LayoutMetrics get layoutMetrics {
    final scoped = AdaptiveScope.maybeOf(this);
    if (scoped != null) return scoped;
    return LayoutMetrics.fromWindowSize(MediaQuery.sizeOf(this), layout: layout);
  }

  WindowSizeClass get sizeClass => layoutMetrics.sizeClass;

  bool get isLandscape => layoutMetrics.isLandscape;
}
