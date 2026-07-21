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
    required this.greeting,
    required this.cardTitle,
    required this.cardBody,
    required this.sectionTitle,
    required this.tileLabel,
    required this.caption,
    required this.bodySmall,
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

  // --- 보호자 홈 (Figma `보호자_홈` 217:2655) ---
  // title(28)/headline(26)과 크기가 겹치지 않아 별도 토큰으로 둔다.
  // 화면에서 copyWith(fontSize:)로 덮어쓰면 Figma가 바뀔 때 추적이 불가능하다.

  /// 인사말 "안녕하세요,\n○○ 보호자님" (24/w800, 2줄)
  final TextStyle greeting;

  /// 카드 제목 "새로운 일과 만들기" (17/w800)
  final TextStyle cardTitle;

  /// 카드 본문 — 목록 항목 제목·빈 상태 문구 (15/w400)
  final TextStyle cardBody;

  /// 섹션 제목 "추천 일과"·"최근 일과" (14/w800)
  final TextStyle sectionTitle;

  /// 추천 타일 라벨 (13/w400, 2줄)
  final TextStyle tileLabel;

  /// 보조 설명 — 카드 부제·"카드 N장" (12/w400)
  final TextStyle caption;

  /// 본문보다 한 단계 작은 설명 (14/w400).
  /// DLP 배지·일과 입력 요약처럼 좁은 폭에 들어가는 문구.
  /// [sectionTitle]과 크기는 같지만 굵기가 달라 별개 토큰이다.
  final TextStyle bodySmall;

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
    greeting: TextStyle(
      fontFamily: fontFamily,
      fontSize: 24,
      fontWeight: FontWeight.w800,
      height: 1.2,
    ),
    cardTitle: TextStyle(
      fontFamily: fontFamily,
      fontSize: 17,
      fontWeight: FontWeight.w800,
      height: 1.0,
    ),
    cardBody: TextStyle(
      fontFamily: fontFamily,
      fontSize: 15,
      fontWeight: FontWeight.w400,
      height: 1.0,
    ),
    sectionTitle: TextStyle(
      fontFamily: fontFamily,
      fontSize: 14,
      fontWeight: FontWeight.w800,
      height: 1.0,
    ),
    tileLabel: TextStyle(
      fontFamily: fontFamily,
      fontSize: 13,
      fontWeight: FontWeight.w400,
      height: 1.2,
    ),
    caption: TextStyle(
      fontFamily: fontFamily,
      fontSize: 12,
      fontWeight: FontWeight.w400,
      height: 1.2,
    ),
    bodySmall: TextStyle(
      fontFamily: fontFamily,
      fontSize: 14,
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
    TextStyle? greeting,
    TextStyle? cardTitle,
    TextStyle? cardBody,
    TextStyle? sectionTitle,
    TextStyle? tileLabel,
    TextStyle? caption,
    TextStyle? bodySmall,
  }) {
    return AppTypography(
      title: title ?? this.title,
      button: button ?? this.button,
      headline: headline ?? this.headline,
      subtitle: subtitle ?? this.subtitle,
      input: input ?? this.input,
      body: body ?? this.body,
      greeting: greeting ?? this.greeting,
      cardTitle: cardTitle ?? this.cardTitle,
      cardBody: cardBody ?? this.cardBody,
      sectionTitle: sectionTitle ?? this.sectionTitle,
      tileLabel: tileLabel ?? this.tileLabel,
      caption: caption ?? this.caption,
      bodySmall: bodySmall ?? this.bodySmall,
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
      greeting: TextStyle.lerp(greeting, other.greeting, t)!,
      cardTitle: TextStyle.lerp(cardTitle, other.cardTitle, t)!,
      cardBody: TextStyle.lerp(cardBody, other.cardBody, t)!,
      sectionTitle: TextStyle.lerp(sectionTitle, other.sectionTitle, t)!,
      tileLabel: TextStyle.lerp(tileLabel, other.tileLabel, t)!,
      caption: TextStyle.lerp(caption, other.caption, t)!,
      bodySmall: TextStyle.lerp(bodySmall, other.bodySmall, t)!,
    );
  }
}
