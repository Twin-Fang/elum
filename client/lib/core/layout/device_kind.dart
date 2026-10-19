import 'dart:math' as math;

import 'package:flutter/painting.dart';

/// 기기 종류: 방향 정책에만 쓴다 (화면 레이아웃은 창 폭 등급으로 가른다)
enum DeviceKind {
  phone,
  tablet;

  /// 물리 화면 짧은 변이 이 값(dp) 이상이면 태블릿 (Material 대화면 기준)
  static const tabletShortestSide = 600.0;

  /// 화면 크기(dp) > 기기 종류. 가로로 들어도 짧은 변으로 가르고, 모르면(0x0) 폰
  static DeviceKind fromLogicalSize(Size logicalSize) {
    final shortestSide = math.min(logicalSize.width, logicalSize.height);
    return shortestSide >= tabletShortestSide
        ? DeviceKind.tablet
        : DeviceKind.phone;
  }
}
