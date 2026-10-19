import 'dart:ui' show FlutterView, PlatformDispatcher, Size;

import 'package:flutter/services.dart';

import 'device_kind.dart';

/// 기기별 허용 방향: 폰은 세로만, 태블릿은 네 방향
///
/// 사용자에게 열리는지는 네이티브 설정(iOS 기기 family, Android 세로 고정)이 정한다.
/// 이 정책은 네이티브가 풀려 있어도 폰이 가로로 돌지 않게 하는 안전장치다.
abstract final class OrientationPolicy {
  static List<DeviceOrientation> allowedOrientationsFor(DeviceKind kind) {
    return switch (kind) {
      DeviceKind.phone => const [DeviceOrientation.portraitUp],
      DeviceKind.tablet => const [
        DeviceOrientation.portraitUp,
        DeviceOrientation.portraitDown,
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ],
    };
  }

  /// 기기 화면 크기로 종류를 정해 허용 방향을 플랫폼에 알린다 (앱 시작 때 한 번)
  ///
  /// 크기를 모르면(안드로이드는 첫 프레임 전 뷰 크기가 0) **잠그지 않는다.** 폰으로 오판해 세로를 걸면
  /// 태블릿이 가로 화면 가운데 세로 창(레터박스)으로 뜬다. 폰은 네이티브 설정이 이미 세로로 묶는다.
  static Future<void> apply({FlutterView? view}) async {
    final targetView = view ?? PlatformDispatcher.instance.views.firstOrNull;
    final logicalSize = targetView == null ? null : _readLogicalSize(targetView);
    if (logicalSize == null) return;

    await SystemChrome.setPreferredOrientations(
      allowedOrientationsFor(DeviceKind.fromLogicalSize(logicalSize)),
    );
  }

  /// 실제 디스플레이 크기(dp)를 먼저 읽고, 없으면 뷰 크기. 둘 다 비면 null
  static Size? _readLogicalSize(FlutterView view) {
    final displaySize = view.display.size / view.display.devicePixelRatio;
    if (displaySize.shortestSide > 0) return displaySize;

    final viewSize = view.physicalSize / view.devicePixelRatio;
    return viewSize.shortestSide > 0 ? viewSize : null;
  }
}
