import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'app_layout.dart';
import 'window_size_class.dart';

/// 지금 창의 레이아웃 정보: 등급, 방향, 높이 부족 여부, 크기 배율
///
/// compact(폰)는 배율을 덮지 않아 현행과 같다. medium·expanded 는
/// `s = clamp(min(창폭/393, 창높이/852), 하한, 상한)` 하나로 `.w` 와 `.h` 를 같이 맞춘다.
@immutable
class LayoutMetrics {
  const LayoutMetrics({
    required this.windowSize,
    required this.sizeClass,
    required this.isLandscape,
    required this.isShortHeight,
    required this.isScaleOverridden,
    required this.scale,
    required this.layout,
  });

  /// 창 크기가 비었거나(첫 프레임) 폭이 0이면 compact 로 둔다
  factory LayoutMetrics.fromWindowSize(
    Size windowSize, {
    AppLayout layout = AppLayout.standard,
  }) {
    final isWindowEmpty = windowSize.width <= 0 || windowSize.height <= 0;
    final sizeClass = isWindowEmpty
        ? WindowSizeClass.compact
        : WindowSizeClass.fromWidth(windowSize.width, layout);
    final isScaleOverridden = sizeClass != WindowSizeClass.compact;

    var scale = 1.0;
    if (isScaleOverridden) {
      final fitScale = math.min(
        windowSize.width / layout.phoneColumnWidth,
        windowSize.height / layout.designHeight,
      );
      scale = fitScale.clamp(layout.minFrameScale, layout.maxFrameScale);
    }

    return LayoutMetrics(
      windowSize: windowSize,
      sizeClass: sizeClass,
      isLandscape: windowSize.width > windowSize.height,
      isShortHeight: !isWindowEmpty && windowSize.height < layout.shortHeightMax,
      isScaleOverridden: isScaleOverridden,
      scale: scale,
      layout: layout,
    );
  }

  final Size windowSize;
  final WindowSizeClass sizeClass;
  final bool isLandscape;

  /// 높이가 [AppLayout.shortHeightMax] 미만 (가로 + 분할 화면 등)
  final bool isShortHeight;

  /// medium·expanded 에서 ScreenUtil 배율을 이 클래스가 정한다 (compact 는 false)
  final bool isScaleOverridden;

  /// 크기 배율 s. compact 는 1.0 (실제 배율은 ScreenUtil 이 창에서 직접 계산)
  final double scale;

  final AppLayout layout;

  /// ScreenUtil 에 줄 디자인 크기. `창 / s` 로 두면 `.w` 와 `.h` 가 모두 s 가 된다
  Size designSizeFor(Size baseDesignSize) {
    if (!isScaleOverridden) return baseDesignSize;
    return Size(windowSize.width / scale, windowSize.height / scale);
  }

  /// 폰 비율 열 폭 (px). 창 폭을 넘지 않는다
  double get phoneColumnWidthPixels {
    return math.min(layout.phoneColumnWidth * scale, windowSize.width);
  }
}
