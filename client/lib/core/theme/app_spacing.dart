import 'package:flutter/material.dart';

/// 간격·크기 토큰. Figma 393×852 프레임 좌표에서 역산한 값이다.
///
/// 좌표를 그대로 박으라는 뜻이 아니라 "이 간격이 의도된 값"이라는 근거다.
/// 다른 화면 크기 대응은 Flutter 레이아웃 위젯으로 흡수한다.
@immutable
class AppSpacing extends ThemeExtension<AppSpacing> {
  const AppSpacing({
    required this.xs,
    required this.sm,
    required this.md,
    required this.lg,
    required this.xl,
    required this.screenH,
    required this.buttonH,
    required this.buttonRadius,
    required this.buttonMarginH,
    required this.fieldH,
    required this.fieldRadius,
    required this.cardRadius,
    required this.headerTop,
  });

  final double xs;
  final double sm;
  final double md;
  final double lg;
  final double xl;

  /// 좌우 기본 여백 — 제목·설명·입력필드가 모두 x=24
  final double screenH;

  // 하단 CTA 버튼 (360×66, r18, x=16)
  final double buttonH;
  final double buttonRadius;
  final double buttonMarginH;

  // 입력 필드 (344×68, r20)
  final double fieldH;
  final double fieldRadius;

  /// 선택 카드 radius (목표 칩·캐릭터 카드)
  final double cardRadius;

  /// 상태바 아래 제목 시작 위치 (y=131)
  final double headerTop;

  static const standard = AppSpacing(
    xs: 8,
    sm: 12,
    md: 16,
    lg: 24,
    xl: 32,
    screenH: 24,
    buttonH: 66,
    buttonRadius: 18,
    buttonMarginH: 16,
    fieldH: 68,
    fieldRadius: 20,
    cardRadius: 20,
    headerTop: 72,
  );

  @override
  AppSpacing copyWith({
    double? xs,
    double? sm,
    double? md,
    double? lg,
    double? xl,
    double? screenH,
    double? buttonH,
    double? buttonRadius,
    double? buttonMarginH,
    double? fieldH,
    double? fieldRadius,
    double? cardRadius,
    double? headerTop,
  }) {
    return AppSpacing(
      xs: xs ?? this.xs,
      sm: sm ?? this.sm,
      md: md ?? this.md,
      lg: lg ?? this.lg,
      xl: xl ?? this.xl,
      screenH: screenH ?? this.screenH,
      buttonH: buttonH ?? this.buttonH,
      buttonRadius: buttonRadius ?? this.buttonRadius,
      buttonMarginH: buttonMarginH ?? this.buttonMarginH,
      fieldH: fieldH ?? this.fieldH,
      fieldRadius: fieldRadius ?? this.fieldRadius,
      cardRadius: cardRadius ?? this.cardRadius,
      headerTop: headerTop ?? this.headerTop,
    );
  }

  @override
  AppSpacing lerp(ThemeExtension<AppSpacing>? other, double t) {
    if (other is! AppSpacing) return this;
    return AppSpacing(
      xs: lerpDouble(xs, other.xs, t),
      sm: lerpDouble(sm, other.sm, t),
      md: lerpDouble(md, other.md, t),
      lg: lerpDouble(lg, other.lg, t),
      xl: lerpDouble(xl, other.xl, t),
      screenH: lerpDouble(screenH, other.screenH, t),
      buttonH: lerpDouble(buttonH, other.buttonH, t),
      buttonRadius: lerpDouble(buttonRadius, other.buttonRadius, t),
      buttonMarginH: lerpDouble(buttonMarginH, other.buttonMarginH, t),
      fieldH: lerpDouble(fieldH, other.fieldH, t),
      fieldRadius: lerpDouble(fieldRadius, other.fieldRadius, t),
      cardRadius: lerpDouble(cardRadius, other.cardRadius, t),
      headerTop: lerpDouble(headerTop, other.headerTop, t),
    );
  }

  static double lerpDouble(double a, double b, double t) => a + (b - a) * t;
}
