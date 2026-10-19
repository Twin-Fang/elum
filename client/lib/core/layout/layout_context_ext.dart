import 'dart:math' as math;

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

  /// 지금 창의 등급·방향·배율. 루트 스코프가 없으면 폰(compact)으로 본다
  ///
  /// 앱은 항상 루트([AdaptiveScreenScale])가 스코프를 준다. 없는 곳은 위젯 테스트뿐이고, 테스트 기본 창(800x600)이
  /// 태블릿으로 판정돼 기존 폰 화면 테스트가 흔들리지 않게 폰으로 둔다.
  LayoutMetrics get layoutMetrics {
    return AdaptiveScope.maybeOf(this) ??
        LayoutMetrics.fromWindowSize(Size.zero, layout: layout);
  }

  WindowSizeClass get sizeClass => layoutMetrics.sizeClass;

  bool get isLandscape => layoutMetrics.isLandscape;

  /// 폰 비율 열 양옆에 남는 폭(dp). 화면 가장자리에 걸치는 연출이 **창 가장자리**까지 가게 할 때 쓴다
  ///
  /// 열 밖에서는 0 (폰, 전폭 화면). 열 안에서는 `MediaQuery` 크기가 열 폭이라 창 폭과의 차이의 절반이다.
  double get frameSideOverhang {
    final metrics = layoutMetrics;
    if (!metrics.isScaleOverridden) return 0;
    return math.max(
      0,
      (metrics.windowSize.width - MediaQuery.sizeOf(this).width) / 2,
    );
  }
}
