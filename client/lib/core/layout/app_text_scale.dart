import 'package:flutter/widgets.dart';

import 'adaptive_scope.dart';

/// 앱 글자 배율: 시스템 글자 크기(1.0~2.0) × 폭 배율(창 폭 / 393, 폰만)
/// 상자는 `.w` 로 폭에 비례하는데 글자는 고정 pt 라 기기마다 비율이 어긋났다 (360 폭은 1.09배로 크게).
/// 시스템 글자를 가장 작게 둔 iPhone(0.82)은 시안보다 작아져 줄이는 쪽은 받지 않는다
/// 키우는 쪽은 2배(WCAG 1.4.4 · 보호자·이룸이 공통)까지. iOS 큰 글자(최대 3.1배)는 2배에서 멈춘다
/// 태블릿은 [LayoutMetrics] 배율 그대로 두고 시스템 배율 범위만 적용
class AppTextScale extends StatelessWidget {
  const AppTextScale({super.key, required this.child});

  final Widget child;

  /// 폭 배율 한계 (작은 폰에서 글자가 너무 작아지지 않게)
  static const _minWidthFactor = 0.9;
  static const _maxWidthFactor = 1.15;

  /// 시스템 글자 크기 범위: 하한 = 시안 크기, 상한 = 200% (화면이 버텨야 하는 최대)
  static const minSystemScaleFactor = 1.0;
  static const maxSystemScaleFactor = 2.0;

  /// 앱 배율 위에 부품 비율을 곱한 배율 (작은 칸 안 글자를 토큰 그대로 줄일 때)
  /// 시스템 비선형 배율(안드로이드 14)과 상한을 그대로 둔다. `TextScaler.linear` 로 다시 만들지 않는다
  static TextScaler scaledBy(BuildContext context, double factor) =>
      _MultipliedTextScaler(MediaQuery.textScalerOf(context), factor);

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final systemScaler = mediaQuery.textScaler.clamp(
      minScaleFactor: minSystemScaleFactor,
      maxScaleFactor: maxSystemScaleFactor,
    );
    return MediaQuery(
      data: mediaQuery.copyWith(
        textScaler: _MultipliedTextScaler(
          systemScaler,
          _widthFactorOf(context),
        ),
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

/// 바탕 배율을 먼저 적용하고 비율을 곱한다 (폭 배율 · 부품 비율 공통)
@immutable
class _MultipliedTextScaler extends TextScaler {
  const _MultipliedTextScaler(this.baseScaler, this.factor);

  final TextScaler baseScaler;
  final double factor;

  @override
  double scale(double fontSize) => baseScaler.scale(fontSize) * factor;

  // TextScaler 가 아직 요구하는 옛 값 (선형 근사)
  @override
  // ignore: deprecated_member_use
  double get textScaleFactor => baseScaler.textScaleFactor * factor;

  @override
  bool operator ==(Object other) =>
      other is _MultipliedTextScaler &&
      other.baseScaler == baseScaler &&
      other.factor == factor;

  @override
  int get hashCode => Object.hash(baseScaler, factor);
}
