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
    required this.borderWidth,
    required this.selectedBorderWidth,
    required this.headerTop,
    required this.ctaTop,
    required this.headerToContent,
    required this.checkSize,
    required this.checkRadius,
    required this.iconSm,
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

  /// 기본 테두리 두께
  final double borderWidth;

  /// 선택 상태 테두리 두께 — 목표 칩·캐릭터 카드 공통 2px
  final double selectedBorderWidth;

  /// 제목 시작 위치. **화면 최상단(y=0) 기준 절대 좌표**다 (Figma y=131).
  ///
  /// Figma 프레임(393×852)은 StatusBar(y=0~59)를 포함하므로 이 값은
  /// 상태바를 뺀 값이 아니다. SafeArea 안에서 그대로 쓰면 상태바 높이만큼
  /// 위로 밀리므로, [ElumScaffold]가 `131 - safeAreaTop`으로 보정해 쓴다.
  final double headerTop;

  /// 하단 CTA 상단 위치 — 화면 최상단 기준 (Figma y=675).
  /// Home Indicator(y=831)와 함께 하단 여백을 역산하는 근거다.
  final double ctaTop;

  /// 헤더 설명 하단(y=227) → 첫 콘텐츠(y=279) 간격.
  /// [xl](32)과 값이 달라 별도 토큰으로 둔다 — 온보딩 전 화면 공통 52다.
  final double headerToContent;

  // --- 선택 표시 ---

  /// 체크박스 한 변. 손가락으로 누르는 최소 크기를 확보한다.
  final double checkSize;

  /// 체크박스 모서리. 값이 xs와 같아도 쓰임이 달라 따로 둔다 —
  /// 간격을 조정한다고 체크 모양까지 바뀌면 안 된다.
  final double checkRadius;

  /// 목록 우측 화살표처럼 글에 곁들이는 작은 아이콘.
  final double iconSm;

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
    borderWidth: 1,
    selectedBorderWidth: 2,
    // Figma 실측 — 화면 최상단 기준 절대 y좌표
    headerTop: 131,
    ctaTop: 675,
    headerToContent: 52,
    checkSize: 24,
    checkRadius: 8,
    iconSm: 20,
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
    double? borderWidth,
    double? selectedBorderWidth,
    double? headerTop,
    double? ctaTop,
    double? headerToContent,
    double? checkSize,
    double? checkRadius,
    double? iconSm,
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
      borderWidth: borderWidth ?? this.borderWidth,
      selectedBorderWidth: selectedBorderWidth ?? this.selectedBorderWidth,
      headerTop: headerTop ?? this.headerTop,
      ctaTop: ctaTop ?? this.ctaTop,
      headerToContent: headerToContent ?? this.headerToContent,
      checkSize: checkSize ?? this.checkSize,
      checkRadius: checkRadius ?? this.checkRadius,
      iconSm: iconSm ?? this.iconSm,
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
      borderWidth: lerpDouble(borderWidth, other.borderWidth, t),
      selectedBorderWidth:
          lerpDouble(selectedBorderWidth, other.selectedBorderWidth, t),
      headerTop: lerpDouble(headerTop, other.headerTop, t),
      ctaTop: lerpDouble(ctaTop, other.ctaTop, t),
      headerToContent: lerpDouble(headerToContent, other.headerToContent, t),
      checkSize: lerpDouble(checkSize, other.checkSize, t),
      checkRadius: lerpDouble(checkRadius, other.checkRadius, t),
      iconSm: lerpDouble(iconSm, other.iconSm, t),
    );
  }

  static double lerpDouble(double a, double b, double t) => a + (b - a) * t;
}
