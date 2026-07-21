import 'package:flutter/material.dart';

/// 앱 전역 타이포그래피 토큰.
///
/// 폰트는 Figma 기준 `TmoneyRoundWind` (둥근 고딕 — 아동 친화적).
/// `Cloudsofa_namgim`(로고 64px)은 파일 미확보라 여기 없다 — 로고는 이미지 에셋으로 처리한다.
@immutable
class AppTypography extends ThemeExtension<AppTypography> {
  const AppTypography({
    required this.title,
    required this.button,
    required this.headline,
    required this.subtitle,
    required this.input,
    required this.body,
  });

  static const fontFamily = 'TmoneyRoundWind';

  /// 화면 제목 (2줄)
  final TextStyle title;

  /// 하단 CTA 버튼
  final TextStyle button;

  final TextStyle headline;
  final TextStyle subtitle;

  /// 입력 필드 텍스트
  final TextStyle input;

  /// 설명 문구·선택 항목 텍스트
  final TextStyle body;

  static const standard = AppTypography(
    title: TextStyle(
      fontFamily: fontFamily,
      fontSize: 28,
      fontWeight: FontWeight.w800,
      height: 1.2,
    ),
    button: TextStyle(
      fontFamily: fontFamily,
      fontSize: 22,
      fontWeight: FontWeight.w800,
      height: 1.0,
    ),
    headline: TextStyle(
      fontFamily: fontFamily,
      fontSize: 26,
      fontWeight: FontWeight.w800,
      height: 1.0,
    ),
    subtitle: TextStyle(
      fontFamily: fontFamily,
      fontSize: 20,
      fontWeight: FontWeight.w800,
      height: 1.0,
    ),
    input: TextStyle(
      fontFamily: fontFamily,
      fontSize: 20,
      fontWeight: FontWeight.w400,
      height: 1.0,
    ),
    body: TextStyle(
      fontFamily: fontFamily,
      fontSize: 16,
      fontWeight: FontWeight.w400,
      height: 1.0,
    ),
  );

  /// 표준 Material 슬롯에 매핑한다.
  /// 기본 Flutter 위젯이 별도 설정 없이도 올바른 스타일로 렌더링되게 하기 위함.
  TextTheme toTextTheme(Color primary, Color secondary) => TextTheme(
        headlineLarge: title.copyWith(color: primary),
        headlineMedium: headline.copyWith(color: primary),
        titleMedium: subtitle.copyWith(color: primary),
        bodyLarge: input.copyWith(color: primary),
        bodyMedium: body.copyWith(color: secondary),
        labelLarge: button,
      );

  @override
  AppTypography copyWith({
    TextStyle? title,
    TextStyle? button,
    TextStyle? headline,
    TextStyle? subtitle,
    TextStyle? input,
    TextStyle? body,
  }) {
    return AppTypography(
      title: title ?? this.title,
      button: button ?? this.button,
      headline: headline ?? this.headline,
      subtitle: subtitle ?? this.subtitle,
      input: input ?? this.input,
      body: body ?? this.body,
    );
  }

  @override
  AppTypography lerp(ThemeExtension<AppTypography>? other, double t) {
    if (other is! AppTypography) return this;
    return AppTypography(
      title: TextStyle.lerp(title, other.title, t)!,
      button: TextStyle.lerp(button, other.button, t)!,
      headline: TextStyle.lerp(headline, other.headline, t)!,
      subtitle: TextStyle.lerp(subtitle, other.subtitle, t)!,
      input: TextStyle.lerp(input, other.input, t)!,
      body: TextStyle.lerp(body, other.body, t)!,
    );
  }
}
