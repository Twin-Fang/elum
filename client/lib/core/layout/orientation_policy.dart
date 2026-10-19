import 'dart:ui' show FlutterView, PlatformDispatcher;

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

  /// 첫 뷰 크기로 기기 종류를 정해 허용 방향을 플랫폼에 알린다 (앱 시작 때 한 번)
  static Future<void> apply({FlutterView? view}) {
    final targetView = view ?? PlatformDispatcher.instance.views.firstOrNull;
    final logicalSize = targetView == null
        ? null
        : targetView.physicalSize / targetView.devicePixelRatio;
    final kind = logicalSize == null
        ? DeviceKind.phone
        : DeviceKind.fromLogicalSize(logicalSize);
    return SystemChrome.setPreferredOrientations(allowedOrientationsFor(kind));
  }
}
