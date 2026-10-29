import 'package:flutter/widgets.dart';

import 'adaptive_scope.dart';

/// 앱 글자 배율: 시스템 글자 크기(1.0 미만은 1.0) × 폭 배율(창 폭 / 393, 폰만)
/// 상자는 `.w` 로 폭에 비례하는데 글자는 고정 pt 라 기기마다 비율이 어긋났다 (360 폭은 1.09배로 크게).
/// 시스템 글자를 가장 작게 둔 iPhone(0.82)은 시안보다 작아져 줄이는 쪽은 받지 않는다. 키우는 쪽은 그대로
/// 태블릿은 [LayoutMetrics] 배율 그대로 두고 최소값만 적용
class AppTextScale extends StatelessWidget {
  const AppTextScale({super.key, required this.child});

  final Widget child;

  /// 폭 배율 한계 (작은 폰에서 글자가 너무 작아지지 않게)
  static const _minWidthFactor = 0.9;
  static const _maxWidthFactor = 1.15;

  /// 시스템 글자 크기 하한 (시안 크기 아래로 줄이지 않는다)
  static const _minSystemScaleFactor = 1.0;

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final systemScaler = mediaQuery.textScaler.clamp(
      minScaleFactor: _minSystemScaleFactor,
    );
    return MediaQuery(
      data: mediaQuery.copyWith(
        textScaler: _WidthTextScaler(systemScaler, _widthFactorOf(context)),
      ),
      child: child,
    );
  }

  /// 폰(compact)만 창 폭 / 393. 루트 없이 세운 위젯 · 태블릿 · 첫 프레임은 1
  double _widthFactorOf(BuildContext context) {
    final metrics = AdaptiveScope.maybeOf(context);
    if (metrics == null || metrics.isScaleOverridden) return 1;
    final windowWidth = metrics.windowSize.width;
    if (windowWidth <= 0) return 1;
    return (windowWidth / metrics.layout.phoneColumnWidth).clamp(
      _minWidthFactor,
      _maxWidthFactor,
    );
  }
}

/// 시스템 배율(접근성 글자 크기, 하한 적용)을 먼저 적용하고 폭 배율을 곱한다
@immutable
class _WidthTextScaler extends TextScaler {
  const _WidthTextScaler(this.systemScaler, this.widthFactor);

  final TextScaler systemScaler;
  final double widthFactor;

  @override
  double scale(double fontSize) => systemScaler.scale(fontSize) * widthFactor;

  // TextScaler 가 아직 요구하는 옛 값 (선형 근사)
  @override
  // ignore: deprecated_member_use
  double get textScaleFactor => systemScaler.textScaleFactor * widthFactor;

  @override
  bool operator ==(Object other) =>
      other is _WidthTextScaler &&
      other.systemScaler == systemScaler &&
      other.widthFactor == widthFactor;

  @override
  int get hashCode => Object.hash(systemScaler, widthFactor);
}
