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
    required this.promptTitle,
    required this.promptBody,
    required this.chipLabel,
    required this.stageLabel,
    required this.cardHeadline,
    required this.cardDescription,
    required this.reviewTitle,
    required this.pinTitle,
    required this.bodySmall,
    required this.childTileTitle,
    required this.ringPercent,
    required this.starsCount,
    required this.editChipLabel,
    required this.childDetailTitle,
    required this.promptPlaceholder,
    required this.promptCaption,
    required this.actionCardTitle,
  });

  static const fontFamily = 'TmoneyRoundWind';

  /// 일과 만들기 흐름 전용 폰트.
  /// Figma가 이 화면군만 Pretendard로 그렸다 — 섞어 쓰는 게 아니라 화면군이 다르다.
  static const promptFontFamily = 'Pretendard';

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

  // --- 일과 만들기 흐름 (Figma 238:1643 등) ---
  // 이 화면군만 Pretendard다. 디자이너가 화면군을 나눴다.

  /// 화면 제목 "오늘은 어떤 준비가 필요한가요?" (30/w600, 중앙정렬)
  final TextStyle promptTitle;

  /// 설명·입력 텍스트 (16)
  final TextStyle promptBody;

  /// 추천 문구 칩 (14/w500)
  final TextStyle chipLabel;

  /// 로딩 화면 단계 문구 (18/w500)
  final TextStyle stageLabel;

  // --- 행동 카드 (Figma 262:5124 / 309:3548) ---
  // 아동이 읽는 문구라 크다. TmoneyRoundWind를 쓴다.

  /// 카드 제목·번호 (30/w800)
  final TextStyle cardHeadline;

  /// 카드 설명 (20/w400, 2줄)
  final TextStyle cardDescription;

  /// 카드확인 화면 제목 "카드 N개가 생성되었어요" (24/w600 Pretendard)
  final TextStyle reviewTitle;

  /// PIN 화면 제목 (28/w800). title(28)과 크기는 같지만 줄간격이 다르다.
  final TextStyle pinTitle;

  /// 본문보다 한 단계 작은 설명 (14/w400).
  /// DLP 배지·일과 입력 요약처럼 좁은 폭에 들어가는 문구.
  /// [sectionTitle]과 크기는 같지만 굵기가 달라 별개 토큰이다.
  final TextStyle bodySmall;

  // --- 홈 일과 목록 (Figma 356:4688 / 356:5079 / 364:8219) ---

  /// 아이 홈 일과 타일 제목 (18/w400).
  final TextStyle childTileTitle;

  /// 진행률 링 중앙 퍼센트 "50%" (12/w800).
  /// caption(12/w400)과 크기는 같지만 굵기가 다르다.
  final TextStyle ringPercent;

  /// 아이_별 화면 누적 별 숫자 (80/w800).
  final TextStyle starsCount;

  // --- 카드확인·아이 상세 (Figma 262:5124 / 309:3548, 2026-07-22 덤프) ---

  /// `이 카드 수정하기` 칩 (14/w600 Pretendard).
  /// chipLabel(14/w500)과 굵기가 달라 별개 토큰이다.
  final TextStyle editChipLabel;

  /// 아이 상세 상단바의 일과 제목 (18/w800).
  /// childTileTitle(18/w400)과 굵기가 달라 별개 토큰이다.
  final TextStyle childDetailTitle;

  // --- 일과 입력 (Figma 238:1846, 2026-07-22 덤프) ---

  /// 일과 입력창 플레이스홀더 (16/w400 Pretendard, style_7YRXS7).
  /// promptBody(16/w500)와 굵기가 달라 별개 토큰이다.
  final TextStyle promptPlaceholder;

  /// 일과 입력 하단 안내 "아이의 정보를 안전하게 보호해요" (12/w500 Pretendard, style_H3KJNZ).
  /// caption(12/w400 TmoneyRoundWind)과 폰트·굵기가 달라 별개 토큰이다.
  final TextStyle promptCaption;

  /// 행동 카드 제목 (25/w800, style_GKEQ8F).
  /// 순서 배지 숫자용 cardHeadline(30/w800)과 크기가 달라 별개 토큰이다.
  final TextStyle actionCardTitle;

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
    promptTitle: TextStyle(
      fontFamily: promptFontFamily,
      fontSize: 30,
      fontWeight: FontWeight.w600,
      height: 1.1,
    ),
    promptBody: TextStyle(
      fontFamily: promptFontFamily,
      fontSize: 16,
      fontWeight: FontWeight.w500,
      height: 1.1,
    ),
    chipLabel: TextStyle(
      fontFamily: promptFontFamily,
      fontSize: 14,
      fontWeight: FontWeight.w500,
      height: 1.0,
    ),
    stageLabel: TextStyle(
      fontFamily: promptFontFamily,
      fontSize: 18,
      fontWeight: FontWeight.w500,
      height: 1.0,
    ),
    cardHeadline: TextStyle(
      fontFamily: fontFamily,
      fontSize: 30,
      fontWeight: FontWeight.w800,
      height: 1.0,
    ),
    cardDescription: TextStyle(
      fontFamily: fontFamily,
      fontSize: 20,
      fontWeight: FontWeight.w400,
      height: 1.2,
    ),
    reviewTitle: TextStyle(
      fontFamily: promptFontFamily,
      fontSize: 24,
      fontWeight: FontWeight.w600,
      height: 1.1,
    ),
    pinTitle: TextStyle(
      fontFamily: fontFamily,
      fontSize: 28,
      fontWeight: FontWeight.w800,
      height: 1.2,
    ),
    bodySmall: TextStyle(
      fontFamily: fontFamily,
      fontSize: 14,
      fontWeight: FontWeight.w400,
      height: 1.0,
    ),
    childTileTitle: TextStyle(
      fontFamily: fontFamily,
      fontSize: 18,
      fontWeight: FontWeight.w400,
      height: 1.0,
    ),
    ringPercent: TextStyle(
      fontFamily: fontFamily,
      fontSize: 12,
      fontWeight: FontWeight.w800,
      height: 1.0,
    ),
    starsCount: TextStyle(
      fontFamily: fontFamily,
      fontSize: 80,
      fontWeight: FontWeight.w800,
      height: 1.0,
    ),
    editChipLabel: TextStyle(
      fontFamily: promptFontFamily,
      fontSize: 14,
      fontWeight: FontWeight.w600,
      height: 1.0,
    ),
    childDetailTitle: TextStyle(
      fontFamily: fontFamily,
      fontSize: 18,
      fontWeight: FontWeight.w800,
      height: 1.0,
    ),
    promptPlaceholder: TextStyle(
      fontFamily: promptFontFamily,
      fontSize: 16,
      fontWeight: FontWeight.w400,
      // Figma는 1em이지만 promptBody(1.1)와 다르면 힌트→입력 전환 때 높이가 튄다
      height: 1.1,
    ),
    promptCaption: TextStyle(
      fontFamily: promptFontFamily,
      fontSize: 12,
      fontWeight: FontWeight.w500,
      height: 1.1,
    ),
    actionCardTitle: TextStyle(
      fontFamily: fontFamily,
      fontSize: 25,
      fontWeight: FontWeight.w800,
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
    TextStyle? promptTitle,
    TextStyle? promptBody,
    TextStyle? chipLabel,
    TextStyle? stageLabel,
    TextStyle? cardHeadline,
    TextStyle? cardDescription,
    TextStyle? reviewTitle,
    TextStyle? pinTitle,
    TextStyle? bodySmall,
    TextStyle? childTileTitle,
    TextStyle? ringPercent,
    TextStyle? starsCount,
    TextStyle? editChipLabel,
    TextStyle? childDetailTitle,
    TextStyle? promptPlaceholder,
    TextStyle? promptCaption,
    TextStyle? actionCardTitle,
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
      promptTitle: promptTitle ?? this.promptTitle,
      promptBody: promptBody ?? this.promptBody,
      chipLabel: chipLabel ?? this.chipLabel,
      stageLabel: stageLabel ?? this.stageLabel,
      cardHeadline: cardHeadline ?? this.cardHeadline,
      cardDescription: cardDescription ?? this.cardDescription,
      reviewTitle: reviewTitle ?? this.reviewTitle,
      pinTitle: pinTitle ?? this.pinTitle,
      bodySmall: bodySmall ?? this.bodySmall,
      childTileTitle: childTileTitle ?? this.childTileTitle,
      ringPercent: ringPercent ?? this.ringPercent,
      starsCount: starsCount ?? this.starsCount,
      editChipLabel: editChipLabel ?? this.editChipLabel,
      childDetailTitle: childDetailTitle ?? this.childDetailTitle,
      promptPlaceholder: promptPlaceholder ?? this.promptPlaceholder,
      promptCaption: promptCaption ?? this.promptCaption,
      actionCardTitle: actionCardTitle ?? this.actionCardTitle,
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
      promptTitle: TextStyle.lerp(promptTitle, other.promptTitle, t)!,
      promptBody: TextStyle.lerp(promptBody, other.promptBody, t)!,
      chipLabel: TextStyle.lerp(chipLabel, other.chipLabel, t)!,
      stageLabel: TextStyle.lerp(stageLabel, other.stageLabel, t)!,
      cardHeadline: TextStyle.lerp(cardHeadline, other.cardHeadline, t)!,
      cardDescription: TextStyle.lerp(cardDescription, other.cardDescription, t)!,
      reviewTitle: TextStyle.lerp(reviewTitle, other.reviewTitle, t)!,
      pinTitle: TextStyle.lerp(pinTitle, other.pinTitle, t)!,
      bodySmall: TextStyle.lerp(bodySmall, other.bodySmall, t)!,
      childTileTitle: TextStyle.lerp(childTileTitle, other.childTileTitle, t)!,
      ringPercent: TextStyle.lerp(ringPercent, other.ringPercent, t)!,
      starsCount: TextStyle.lerp(starsCount, other.starsCount, t)!,
      editChipLabel: TextStyle.lerp(editChipLabel, other.editChipLabel, t)!,
      childDetailTitle:
          TextStyle.lerp(childDetailTitle, other.childDetailTitle, t)!,
      promptPlaceholder:
          TextStyle.lerp(promptPlaceholder, other.promptPlaceholder, t)!,
      promptCaption: TextStyle.lerp(promptCaption, other.promptCaption, t)!,
      actionCardTitle:
          TextStyle.lerp(actionCardTitle, other.actionCardTitle, t)!,
    );
  }
}
