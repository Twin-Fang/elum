import 'package:flutter/material.dart';

import '../../features/onboarding/domain/character.dart';

/// 캐릭터 선택 상태의 배경·테두리 색 한 쌍.
typedef SelectionColors = ({Color fill, Color border});

/// 앱 전역 색상 토큰.
///
/// 값의 출처는 Figma `이룸` 파일이며, 상세 근거는 docs/design-system.md에 있다.
/// 위젯에서 `Color(0x...)`를 직접 쓰지 말고 반드시 이 토큰을 경유한다.
@immutable
class AppColors extends ThemeExtension<AppColors> {
  const AppColors({
    required this.background,
    required this.surface,
    required this.textPrimary,
    required this.textSecondary,
    required this.textPlaceholder,
    required this.border,
    required this.chipLabel,
    required this.buttonEnabled,
    required this.buttonEnabledText,
    required this.buttonDisabled,
    required this.buttonDisabledText,
    required this.highlightFill,
    required this.highlightBorder,
    required this.goalSelectedFill,
    required this.goalSelectedBorder,
    required this.foxSelectedFill,
    required this.foxSelectedBorder,
    required this.catSelectedFill,
    required this.catSelectedBorder,
    required this.brandPeach,
    required this.brandOrange,
    required this.accentYellow,
    required this.splashTop,
    required this.splashBottom,
    required this.splashHill,
    required this.splashHillGlow,
    required this.splashTitle,
  });

  /// 화면 배경 (따뜻한 아이보리)
  final Color background;

  /// 카드·입력 필드 배경
  final Color surface;

  final Color textPrimary;
  final Color textSecondary;
  final Color textPlaceholder;

  /// 기본 테두리 (1px)
  final Color border;

  /// 선택 항목 문구색. Figma가 #000000이라 textPrimary(#242634)와 다르다.
  final Color chipLabel;

  // 하단 CTA 버튼 — Figma 컴포넌트셋 187:299의 두 variant
  final Color buttonEnabled;
  final Color buttonEnabledText;
  final Color buttonDisabled;
  final Color buttonDisabledText;

  // 강조 표면 — 보호자 화면의 마스킹 결과·요약 배지 등.
  // Figma 명세가 없는 임시 값이다. 디자인이 확정되면 교체한다.
  final Color highlightFill;
  final Color highlightBorder;

  // 선택 상태 — 용도마다 색이 다르다. 하나로 묶으면 표현이 불가능하다.
  // 목표 칩 (Figma 온보딩_목표_선택 204:1147)
  final Color goalSelectedFill;
  final Color goalSelectedBorder;

  // 캐릭터 카드는 캐릭터마다 다르다
  // (Figma 온보딩_캐릭터_여우 204:1121 / 온보딩_캐릭터_고양이 204:1134)
  final Color foxSelectedFill;
  final Color foxSelectedBorder;
  final Color catSelectedFill;
  final Color catSelectedBorder;

  final Color brandPeach;
  final Color brandOrange;

  /// 별 보상
  final Color accentYellow;

  // 시작 화면 (Figma `시작` 238:1808)
  /// 배경 그라데이션 시작색
  final Color splashTop;
  /// 배경 그라데이션 끝색
  final Color splashBottom;
  /// 하단 언덕 기본색
  final Color splashHill;
  /// 언덕 방사형 그라데이션의 밝은 쪽
  final Color splashHillGlow;
  /// 시작 화면 강조 문구색
  final Color splashTitle;

  static const light = AppColors(
    background: Color(0xFFF7F2EF),
    surface: Color(0xFFFFFFFF),
    textPrimary: Color(0xFF242634),
    textSecondary: Color(0xFF898B98),
    textPlaceholder: Color(0xFFDADADA),
    border: Color(0xFFEFEFEF),
    chipLabel: Color(0xFF000000),
    buttonEnabled: Color(0xFF242634),
    buttonEnabledText: Color(0xFFFFFFFF),
    buttonDisabled: Color(0xFF818393),
    buttonDisabledText: Color(0x80FFFFFF), // rgba(255,255,255,0.5)
    highlightFill: Color(0xFFFFDAC7),
    highlightBorder: Color(0xFFEB9B73),
    goalSelectedFill: Color(0xFFB5EAEC),
    goalSelectedBorder: Color(0xFF93DBCC),
    foxSelectedFill: Color(0xFFFFDAC7),
    foxSelectedBorder: Color(0xFFEB9B73),
    catSelectedFill: Color(0xFFCED8FF),
    catSelectedBorder: Color(0xFF9CADF1),
    brandPeach: Color(0xFFFFC9BB),
    brandOrange: Color(0xFFFF8B22),
    accentYellow: Color(0xFFFFD629),
    splashTop: Color(0xFFFFFFFF),
    splashBottom: Color(0xFFFFFADB),
    splashHill: Color(0xFFFFD629),
    splashHillGlow: Color(0xFFFFF2BB),
    splashTitle: Color(0xFF230D60),
  );

  /// 캐릭터별 선택 색. enum과 1:1이므로 switch로 매핑한다.
  /// 새 캐릭터를 추가하면 여기서 컴파일 에러가 나 색 누락을 막는다.
  /// (AppAssets.character()와 같은 패턴)
  SelectionColors characterSelected(CardCharacter character) =>
      switch (character) {
        CardCharacter.fox => (fill: foxSelectedFill, border: foxSelectedBorder),
        CardCharacter.cat => (fill: catSelectedFill, border: catSelectedBorder),
      };

  @override
  AppColors copyWith({
    Color? background,
    Color? surface,
    Color? textPrimary,
    Color? textSecondary,
    Color? textPlaceholder,
    Color? border,
    Color? chipLabel,
    Color? buttonEnabled,
    Color? buttonEnabledText,
    Color? buttonDisabled,
    Color? buttonDisabledText,
    Color? highlightFill,
    Color? highlightBorder,
    Color? goalSelectedFill,
    Color? goalSelectedBorder,
    Color? foxSelectedFill,
    Color? foxSelectedBorder,
    Color? catSelectedFill,
    Color? catSelectedBorder,
    Color? brandPeach,
    Color? brandOrange,
    Color? accentYellow,
    Color? splashTop,
    Color? splashBottom,
    Color? splashHill,
    Color? splashHillGlow,
    Color? splashTitle,
  }) {
    return AppColors(
      background: background ?? this.background,
      surface: surface ?? this.surface,
      textPrimary: textPrimary ?? this.textPrimary,
      textSecondary: textSecondary ?? this.textSecondary,
      textPlaceholder: textPlaceholder ?? this.textPlaceholder,
      border: border ?? this.border,
      chipLabel: chipLabel ?? this.chipLabel,
      buttonEnabled: buttonEnabled ?? this.buttonEnabled,
      buttonEnabledText: buttonEnabledText ?? this.buttonEnabledText,
      buttonDisabled: buttonDisabled ?? this.buttonDisabled,
      buttonDisabledText: buttonDisabledText ?? this.buttonDisabledText,
      highlightFill: highlightFill ?? this.highlightFill,
      highlightBorder: highlightBorder ?? this.highlightBorder,
      goalSelectedFill: goalSelectedFill ?? this.goalSelectedFill,
      goalSelectedBorder: goalSelectedBorder ?? this.goalSelectedBorder,
      foxSelectedFill: foxSelectedFill ?? this.foxSelectedFill,
      foxSelectedBorder: foxSelectedBorder ?? this.foxSelectedBorder,
      catSelectedFill: catSelectedFill ?? this.catSelectedFill,
      catSelectedBorder: catSelectedBorder ?? this.catSelectedBorder,
      brandPeach: brandPeach ?? this.brandPeach,
      brandOrange: brandOrange ?? this.brandOrange,
      accentYellow: accentYellow ?? this.accentYellow,
      splashTop: splashTop ?? this.splashTop,
      splashBottom: splashBottom ?? this.splashBottom,
      splashHill: splashHill ?? this.splashHill,
      splashHillGlow: splashHillGlow ?? this.splashHillGlow,
      splashTitle: splashTitle ?? this.splashTitle,
    );
  }

  @override
  AppColors lerp(ThemeExtension<AppColors>? other, double t) {
    if (other is! AppColors) return this;
    return AppColors(
      background: Color.lerp(background, other.background, t)!,
      surface: Color.lerp(surface, other.surface, t)!,
      textPrimary: Color.lerp(textPrimary, other.textPrimary, t)!,
      textSecondary: Color.lerp(textSecondary, other.textSecondary, t)!,
      textPlaceholder: Color.lerp(textPlaceholder, other.textPlaceholder, t)!,
      border: Color.lerp(border, other.border, t)!,
      chipLabel: Color.lerp(chipLabel, other.chipLabel, t)!,
      buttonEnabled: Color.lerp(buttonEnabled, other.buttonEnabled, t)!,
      buttonEnabledText: Color.lerp(buttonEnabledText, other.buttonEnabledText, t)!,
      buttonDisabled: Color.lerp(buttonDisabled, other.buttonDisabled, t)!,
      buttonDisabledText: Color.lerp(buttonDisabledText, other.buttonDisabledText, t)!,
      highlightFill: Color.lerp(highlightFill, other.highlightFill, t)!,
      highlightBorder:
          Color.lerp(highlightBorder, other.highlightBorder, t)!,
      goalSelectedFill:
          Color.lerp(goalSelectedFill, other.goalSelectedFill, t)!,
      goalSelectedBorder:
          Color.lerp(goalSelectedBorder, other.goalSelectedBorder, t)!,
      foxSelectedFill: Color.lerp(foxSelectedFill, other.foxSelectedFill, t)!,
      foxSelectedBorder:
          Color.lerp(foxSelectedBorder, other.foxSelectedBorder, t)!,
      catSelectedFill: Color.lerp(catSelectedFill, other.catSelectedFill, t)!,
      catSelectedBorder:
          Color.lerp(catSelectedBorder, other.catSelectedBorder, t)!,
      brandPeach: Color.lerp(brandPeach, other.brandPeach, t)!,
      brandOrange: Color.lerp(brandOrange, other.brandOrange, t)!,
      accentYellow: Color.lerp(accentYellow, other.accentYellow, t)!,
      splashTop: Color.lerp(splashTop, other.splashTop, t)!,
      splashBottom: Color.lerp(splashBottom, other.splashBottom, t)!,
      splashHill: Color.lerp(splashHill, other.splashHill, t)!,
      splashHillGlow: Color.lerp(splashHillGlow, other.splashHillGlow, t)!,
      splashTitle: Color.lerp(splashTitle, other.splashTitle, t)!,
    );
  }
}
