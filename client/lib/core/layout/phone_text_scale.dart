import 'package:flutter/widgets.dart';

import 'adaptive_scope.dart';

/// 폰 글자 배율: 시스템 글자 크기 × 폭 배율(창 폭 / 393)
/// 상자는 `.w` 로 폭에 비례하는데 글자는 고정 pt 라 기기마다 비율이 어긋났다
/// (넓은 iPhone 은 글자가 작게, 좁은 안드로이드는 크게). 폰(compact)만 맞추고 태블릿은 [LayoutMetrics] 배율 그대로
class PhoneTextScale extends StatelessWidget {
  const PhoneTextScale({super.key, required this.child});

  final Widget child;

  /// 폭 배율 한계 (작은 폰에서 글자가 너무 작아지지 않게)
  static const _minWidthFactor = 0.9;
  static const _maxWidthFactor = 1.15;

  /// 이보다 덜 다르면 393 폭으로 보고 그대로 둔다
  static const _sameWidthTolerance = 0.001;

  @override
  Widget build(BuildContext context) {
    final metrics = AdaptiveScope.maybeOf(context);
    // 루트 없이 세운 위젯 · 태블릿 · 첫 프레임은 그대로
    if (metrics == null || metrics.isScaleOverridden) return child;
    final windowWidth = metrics.windowSize.width;
    if (windowWidth <= 0) return child;

    final widthFactor = (windowWidth / metrics.layout.phoneColumnWidth).clamp(
      _minWidthFactor,
      _maxWidthFactor,
    );
    if ((widthFactor - 1).abs() < _sameWidthTolerance) return child;

    final mediaQuery = MediaQuery.of(context);
    return MediaQuery(
      data: mediaQuery.copyWith(
        textScaler: _WidthTextScaler(mediaQuery.textScaler, widthFactor),
      ),
      child: child,
    );
  }
}

/// 시스템 배율(접근성 글자 크기)을 먼저 적용하고 폭 배율을 곱한다
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
