import 'package:flutter/material.dart';

import '../../features/onboarding/domain/character.dart';

/// 캐릭터 선택 상태의 배경·테두리 색 한 쌍.
typedef SelectionColors = ({Color fill, Color border});

/// 앱 전역 색상 토큰. **앱의 모든 색은 이 파일 하나에 모인다.**
///
/// 값의 출처는 Figma `이룸` 파일이며, 상세 근거는 docs/design-system.md에 있다.
/// 위젯에서 `Color(0x...)`를 직접 쓰지 말고 반드시 이 토큰을 경유한다.
///
/// ## 같은 색이어도 쓰임이 다르면 토큰을 나눈다 ⚠️
///
/// 값이 같다고 하나로 합치지 않는다. **합치면 한쪽만 바꿔야 할 때 못 바꾼다.**
///
/// ```dart
/// catSelectedBorder: Color(0xFF9CADF1),  // 캐릭터 카드 선택 테두리
/// homeCardTitle:     Color(0xFF9CADF1),  // 홈 카드 제목  ← 값이 같아도 따로
/// ```
///
/// 디자이너가 홈 카드 제목만 바꿔도 캐릭터 선택은 그대로여야 한다.
/// 중복 상수 몇 줄이 늘어나는 비용보다, 색이 엉뚱한 데까지 번지는 비용이 크다.
///
/// **판단 기준** — 두 자리가 "항상 같이 바뀌어야 하는가?"
/// 예(같은 의미)면 공유하고, 아니면(우연히 같은 값이면) 나눈다.
///
/// ## 토큰을 추가할 때 고칠 5곳
///
/// 하나라도 빠지면 조용히 어긋난다. `lerp` 누락은 테마 전환 때만 드러난다.
///
/// 1. 필드 선언 (용도 주석 + Figma 노드 ID)
/// 2. 생성자 `required this.x`
/// 3. [light] 인스턴스 값
/// 4. [copyWith]
/// 5. [lerp]
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
    required this.pinDotEmpty,
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
    required this.splashOrbGlowCore,
    required this.splashOrbGlowHalo,
    required this.splashTitle,
    required this.homeCardGradientStart,
    required this.homeCardGradientEnd,
    required this.homeCardTitle,
    required this.homeCardShadow,
    required this.glassSurface,
    required this.glassChip,
    required this.promptMuted,
    required this.glassShadow,
    required this.auroraMint,
    required this.auroraViolet,
    required this.auroraYellow,
    required this.stageDone,
    required this.stagePending,
    required this.stagePendingText,
    required this.checkDone,
    required this.checkPending,
    required this.rewardBackdropTop,
    required this.rewardBackdropBottom,
    required this.rewardStar,
    required this.rewardStarGlow,
    required this.rewardStarGreen,
    required this.rewardStarPurple,
    required this.rewardButton,
    required this.rewardGroundShadow,
    required this.childEmptyShadow,
    required this.routineTileBg,
    required this.routineRingTrack,
    required this.routineRingProgress,
    required this.childTileDone,
    required this.starCount,
    required this.starsNumberStart,
    required this.editChipBg,
    required this.editChipLabel,
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

  /// PIN 입력 전 빈 점 (Figma 238:1996 Group 22)
  final Color pinDotEmpty;


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
  /// 새싹 구슬 glow — 안쪽 진한 코어 (Figma effect_WJJJ2E rgba(0,255,208))
  final Color splashOrbGlowCore;
  /// 새싹 구슬 glow — 바깥쪽 넓게 번지는 헤일로
  final Color splashOrbGlowHalo;
  /// 시작 화면 강조 문구색
  final Color splashTitle;

  // 보호자 홈 (Figma `보호자_홈` 217:2655)
  /// "새로운 일과 만들기" 카드 그라데이션 시작색 (134deg)
  final Color homeCardGradientStart;
  /// 같은 그라데이션 끝색
  final Color homeCardGradientEnd;
  /// 같은 카드의 제목 문구색.
  /// catSelectedBorder와 값이 같지만(#9CADF1) 쓰임이 달라 분리한다 —
  /// 캐릭터 선택 테두리가 바뀌어도 홈 카드는 따라가면 안 된다.
  final Color homeCardTitle;
  /// 같은 카드의 그림자 (Figma 0px 4px 10px rgba(35,13,96,0.1))
  final Color homeCardShadow;

  // 일과 만들기 흐름 (Figma 238:1643) — 움직이는 배경 위의 유리 표면.
  // 반투명이라 뒤 색이 비쳐야 하므로 alpha를 담은 값이다.
  /// 입력창 (rgba(255,255,255,0.6))
  final Color glassSurface;
  /// 추천 칩 (rgba(255,255,255,0.5))
  final Color glassChip;
  /// 흐린 안내 문구 (rgba(36,38,52,0.4))
  final Color promptMuted;
  /// 유리 표면 그림자 (rgba(0,0,0,0.05))
  final Color glassShadow;
  /// 배경 그라데이션 — 민트
  final Color auroraMint;
  /// 배경 그라데이션 — 보라
  final Color auroraViolet;
  /// 배경 그라데이션 — 노랑
  final Color auroraYellow;
  /// 로딩 완료 단계 — 채운 원·진한 문구 (rgba(36,38,52,0.8))
  final Color stageDone;
  /// 로딩 대기 단계 — 빈 원 테두리 (rgba(36,38,52,0.6))
  final Color stagePending;
  /// 로딩 대기 단계 문구 (rgba(36,38,52,0.5))
  final Color stagePendingText;

  // 아이 모드 (Figma 309:3548 / 309:4055)
  /// 아이 홈 체크 완료 원
  final Color checkDone;
  /// 아이 홈 체크 전 테두리 (8px)
  final Color checkPending;
  /// 보상 화면 배경 위 (어두워야 별이 빛난다)
  final Color rewardBackdropTop;
  /// 보상 화면 배경 아래
  final Color rewardBackdropBottom;
  /// 보상 큰 별
  final Color rewardStar;
  /// 큰 별 주변 빛 (rgba(208,255,0,0.3))
  final Color rewardStarGlow;
  /// 작은 별 — 초록
  final Color rewardStarGreen;
  /// 작은 별 — 보라
  final Color rewardStarPurple;
  /// 보상 화면 CTA
  final Color rewardButton;
  /// 보상 캐릭터 발밑 그림자 (Figma Ellipse 23 — 어두운 배경용)
  final Color rewardGroundShadow;
  /// 아이 홈 빈 상태 캐릭터 발밑 그림자 (Figma Ellipse 2 — 밝은 배경용).
  /// 보상 화면 그림자와 배경이 달라 항상 따로 바뀐다 — 토큰을 나눈다.
  final Color childEmptyShadow;

  // 홈 일과 목록 (Figma 356:4688 / 309:3739 / 356:5079)
  /// 일과 타일·펼침 컨테이너·빈 상태 배경 (#EEE9E6)
  final Color routineTileBg;
  /// 진행률 링 트랙. checkPending과 값이 같지만(#C9D6D4) 쓰임이 달라 분리 —
  /// 아이 체크 버튼 테두리가 바뀌어도 링 트랙은 따라가면 안 된다.
  final Color routineRingTrack;
  /// 진행률 링 채움·퍼센트 문구. checkDone(#55CFBA)과 분리, 같은 이유.
  final Color routineRingProgress;
  /// 아이 홈 완료된 일과 타일 배경 (#B5EAEC). goalSelectedFill과 값만 같다.
  final Color childTileDone;
  /// 별 배지 숫자 (#CB9500)
  final Color starCount;
  /// 아이_별 화면 숫자 그라데이션 시작 (#FFDD00 → 흰색)
  final Color starsNumberStart;

  // 카드확인 (Figma 262:5124, 2026-07-22 덤프)
  /// `이 카드 수정하기` 칩 배경 (#EEE9E6). routineTileBg와 값만 같다 —
  /// 일과 타일이 바뀌어도 수정 칩은 따라가면 안 된다.
  final Color editChipBg;
  /// 같은 칩의 문구색 (#000000). chipLabel(선택 항목)과 쓰임이 달라 분리한다.
  final Color editChipLabel;

  static const light = AppColors(
    background: Color(0xFFF7F2EF),
    surface: Color(0xFFFFFFFF),
    textPrimary: Color(0xFF242634),
    textSecondary: Color(0xFF898B98),
    textPlaceholder: Color(0xFFDADADA),
    border: Color(0xFFEFEFEF),
    chipLabel: Color(0xFF000000),
    pinDotEmpty: Color(0xFFCDC8C3),
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
    splashOrbGlowCore: Color(0xE600FFD0),
    splashOrbGlowHalo: Color(0x9900FFD0),
    splashTitle: Color(0xFF230D60),
    homeCardGradientStart: Color(0xFFF9F4FF),
    homeCardGradientEnd: Color(0xFFE9EEFF),
    homeCardTitle: Color(0xFF9CADF1),
    homeCardShadow: Color(0x1A230D60), // rgba(35,13,96,0.1)
    glassSurface: Color(0x99FFFFFF), // rgba(255,255,255,0.6)
    glassChip: Color(0x80FFFFFF), // rgba(255,255,255,0.5)
    promptMuted: Color(0x66242634), // rgba(36,38,52,0.4)
    glassShadow: Color(0x0D000000),
    auroraMint: Color(0xFF7BFFE5),
    auroraViolet: Color(0xFFD16FFF),
    auroraYellow: Color(0xFFFCE551),
    stageDone: Color(0xCC242634),
    stagePending: Color(0x99242634),
    stagePendingText: Color(0x80242634),
    checkDone: Color(0xFF55CFBA),
    checkPending: Color(0xFFC9D6D4),
    rewardBackdropTop: Color(0xFF0C0D1A),
    rewardBackdropBottom: Color(0xFF242634),
    rewardStar: Color(0xFFD0FF00),
    rewardStarGlow: Color(0x4DD0FF00),
    rewardStarGreen: Color(0xFF86FCA3),
    rewardStarPurple: Color(0xFFA186FC),
    rewardButton: Color(0xFF55CFBA),
    rewardGroundShadow: Color(0xFF121215),
    childEmptyShadow: Color(0x4D969696),
    routineTileBg: Color(0xFFEEE9E6),
    routineRingTrack: Color(0xFFC9D6D4),
    routineRingProgress: Color(0xFF55CFBA),
    childTileDone: Color(0xFFB5EAEC),
    starCount: Color(0xFFCB9500),
    starsNumberStart: Color(0xFFFFDD00),
    editChipBg: Color(0xFFEEE9E6),
    editChipLabel: Color(0xFF000000),
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
    Color? pinDotEmpty,
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
    Color? splashOrbGlowCore,
    Color? splashOrbGlowHalo,
    Color? splashTitle,
    Color? homeCardGradientStart,
    Color? homeCardGradientEnd,
    Color? homeCardTitle,
    Color? homeCardShadow,
    Color? glassSurface,
    Color? glassChip,
    Color? promptMuted,
    Color? glassShadow,
    Color? auroraMint,
    Color? auroraViolet,
    Color? auroraYellow,
    Color? stageDone,
    Color? stagePending,
    Color? stagePendingText,
    Color? checkDone,
    Color? checkPending,
    Color? rewardBackdropTop,
    Color? rewardBackdropBottom,
    Color? rewardStar,
    Color? rewardStarGlow,
    Color? rewardStarGreen,
    Color? rewardStarPurple,
    Color? rewardButton,
    Color? rewardGroundShadow,
    Color? childEmptyShadow,
    Color? routineTileBg,
    Color? routineRingTrack,
    Color? routineRingProgress,
    Color? childTileDone,
    Color? starCount,
    Color? starsNumberStart,
    Color? editChipBg,
    Color? editChipLabel,
  }) {
    return AppColors(
      background: background ?? this.background,
      surface: surface ?? this.surface,
      textPrimary: textPrimary ?? this.textPrimary,
      textSecondary: textSecondary ?? this.textSecondary,
      textPlaceholder: textPlaceholder ?? this.textPlaceholder,
      border: border ?? this.border,
      chipLabel: chipLabel ?? this.chipLabel,
      pinDotEmpty: pinDotEmpty ?? this.pinDotEmpty,
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
      splashOrbGlowCore: splashOrbGlowCore ?? this.splashOrbGlowCore,
      splashOrbGlowHalo: splashOrbGlowHalo ?? this.splashOrbGlowHalo,
      splashTitle: splashTitle ?? this.splashTitle,
      homeCardGradientStart:
          homeCardGradientStart ?? this.homeCardGradientStart,
      homeCardGradientEnd: homeCardGradientEnd ?? this.homeCardGradientEnd,
      homeCardTitle: homeCardTitle ?? this.homeCardTitle,
      homeCardShadow: homeCardShadow ?? this.homeCardShadow,
      glassSurface: glassSurface ?? this.glassSurface,
      glassChip: glassChip ?? this.glassChip,
      promptMuted: promptMuted ?? this.promptMuted,
      glassShadow: glassShadow ?? this.glassShadow,
      auroraMint: auroraMint ?? this.auroraMint,
      auroraViolet: auroraViolet ?? this.auroraViolet,
      auroraYellow: auroraYellow ?? this.auroraYellow,
      stageDone: stageDone ?? this.stageDone,
      stagePending: stagePending ?? this.stagePending,
      stagePendingText: stagePendingText ?? this.stagePendingText,
      checkDone: checkDone ?? this.checkDone,
      checkPending: checkPending ?? this.checkPending,
      rewardBackdropTop: rewardBackdropTop ?? this.rewardBackdropTop,
      rewardBackdropBottom: rewardBackdropBottom ?? this.rewardBackdropBottom,
      rewardStar: rewardStar ?? this.rewardStar,
      rewardStarGlow: rewardStarGlow ?? this.rewardStarGlow,
      rewardStarGreen: rewardStarGreen ?? this.rewardStarGreen,
      rewardStarPurple: rewardStarPurple ?? this.rewardStarPurple,
      rewardButton: rewardButton ?? this.rewardButton,
      rewardGroundShadow: rewardGroundShadow ?? this.rewardGroundShadow,
      childEmptyShadow: childEmptyShadow ?? this.childEmptyShadow,
      routineTileBg: routineTileBg ?? this.routineTileBg,
      routineRingTrack: routineRingTrack ?? this.routineRingTrack,
      routineRingProgress: routineRingProgress ?? this.routineRingProgress,
      childTileDone: childTileDone ?? this.childTileDone,
      starCount: starCount ?? this.starCount,
      starsNumberStart: starsNumberStart ?? this.starsNumberStart,
      editChipBg: editChipBg ?? this.editChipBg,
      editChipLabel: editChipLabel ?? this.editChipLabel,
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
      pinDotEmpty: Color.lerp(pinDotEmpty, other.pinDotEmpty, t)!,
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
      splashOrbGlowCore:
          Color.lerp(splashOrbGlowCore, other.splashOrbGlowCore, t)!,
      splashOrbGlowHalo:
          Color.lerp(splashOrbGlowHalo, other.splashOrbGlowHalo, t)!,
      splashTitle: Color.lerp(splashTitle, other.splashTitle, t)!,
      homeCardGradientStart: Color.lerp(
          homeCardGradientStart, other.homeCardGradientStart, t)!,
      homeCardGradientEnd:
          Color.lerp(homeCardGradientEnd, other.homeCardGradientEnd, t)!,
      homeCardTitle: Color.lerp(homeCardTitle, other.homeCardTitle, t)!,
      homeCardShadow: Color.lerp(homeCardShadow, other.homeCardShadow, t)!,
      glassSurface: Color.lerp(glassSurface, other.glassSurface, t)!,
      glassChip: Color.lerp(glassChip, other.glassChip, t)!,
      promptMuted: Color.lerp(promptMuted, other.promptMuted, t)!,
      glassShadow: Color.lerp(glassShadow, other.glassShadow, t)!,
      auroraMint: Color.lerp(auroraMint, other.auroraMint, t)!,
      auroraViolet: Color.lerp(auroraViolet, other.auroraViolet, t)!,
      auroraYellow: Color.lerp(auroraYellow, other.auroraYellow, t)!,
      stageDone: Color.lerp(stageDone, other.stageDone, t)!,
      stagePending: Color.lerp(stagePending, other.stagePending, t)!,
      stagePendingText: Color.lerp(stagePendingText, other.stagePendingText, t)!,
      checkDone: Color.lerp(checkDone, other.checkDone, t)!,
      checkPending: Color.lerp(checkPending, other.checkPending, t)!,
      rewardBackdropTop: Color.lerp(rewardBackdropTop, other.rewardBackdropTop, t)!,
      rewardBackdropBottom: Color.lerp(rewardBackdropBottom, other.rewardBackdropBottom, t)!,
      rewardStar: Color.lerp(rewardStar, other.rewardStar, t)!,
      rewardStarGlow: Color.lerp(rewardStarGlow, other.rewardStarGlow, t)!,
      rewardStarGreen: Color.lerp(rewardStarGreen, other.rewardStarGreen, t)!,
      rewardStarPurple: Color.lerp(rewardStarPurple, other.rewardStarPurple, t)!,
      rewardButton: Color.lerp(rewardButton, other.rewardButton, t)!,
      rewardGroundShadow:
          Color.lerp(rewardGroundShadow, other.rewardGroundShadow, t)!,
      childEmptyShadow:
          Color.lerp(childEmptyShadow, other.childEmptyShadow, t)!,
      routineTileBg: Color.lerp(routineTileBg, other.routineTileBg, t)!,
      routineRingTrack:
          Color.lerp(routineRingTrack, other.routineRingTrack, t)!,
      routineRingProgress:
          Color.lerp(routineRingProgress, other.routineRingProgress, t)!,
      childTileDone: Color.lerp(childTileDone, other.childTileDone, t)!,
      starCount: Color.lerp(starCount, other.starCount, t)!,
      starsNumberStart:
          Color.lerp(starsNumberStart, other.starsNumberStart, t)!,
      editChipBg: Color.lerp(editChipBg, other.editChipBg, t)!,
      editChipLabel: Color.lerp(editChipLabel, other.editChipLabel, t)!,
    );
  }
}
