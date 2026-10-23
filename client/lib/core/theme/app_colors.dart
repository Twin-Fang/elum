import 'package:flutter/material.dart';

import '../../shared/models/character.dart';

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
    required this.buttonNeutral,
    required this.buttonNeutralText,
    required this.sheetHandle,
    required this.sheetTitleText,
    required this.dialogTitleText,
    required this.dialogNeutral,
    required this.dialogNeutralText,
    required this.dialogDanger,
    required this.danger,
    required this.dangerText,
    required this.highlightFill,
    required this.highlightBorder,
    required this.goalSelectedFill,
    required this.goalSelectedBorder,
    required this.libraryNewOutline,
    required this.talkOriginBandFill,
    required this.talkOriginBandAction,
    required this.talkCardBorder,
    required this.talkTitleText,
    required this.talkMetaText,
    required this.talkMetaIcon,
    required this.talkPopularCardFill,
    required this.metaDivider,
    required this.talkSectionDivider,
    required this.talkChoiceSelectedFill,
    required this.talkChoiceSelectedBorder,
    required this.talkChoiceRadioBorder,
    required this.talkAccentText,
    required this.talkPanelFill,
    required this.talkCommentFill,
    required this.talkCommentMineName,
    required this.talkImportGroupSelectedFill,
    required this.talkImportGroupSelectedStroke,
    required this.talkCommentFieldFill,
    required this.talkBlurChoicePanelFill,
    required this.talkBlurChoiceSelectedFill,
    required this.talkBlurChoiceFill,
    required this.talkBlurChoiceLabel,
    required this.talkNoteText,
    required this.talkNoteHint,
    required this.foxSelectedFill,
    required this.foxSelectedBorder,
    required this.catSelectedFill,
    required this.catSelectedBorder,
    required this.brandPeach,
    required this.brandOrange,
    required this.accentYellow,
    required this.splashPlain,
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
    required this.navBackground,
    required this.navDivider,
    required this.navIconSelected,
    required this.navIconUnselected,
    required this.navSelectedFill,
    required this.navItemUnselected,
    required this.folderFill,
    required this.folderStroke,
    required this.libraryTileLabel,
    required this.homeCardShadow,
    required this.homeCardIconBg,
    required this.glassSurface,
    required this.glassChip,
    required this.promptMuted,
    required this.glassShadow,
    required this.auroraMint,
    required this.auroraViolet,
    required this.auroraYellow,
    required this.auroraRewardViolet,
    required this.auroraRewardPink,
    required this.auroraRewardRose,
    required this.auroraPreparingHaze,
    required this.auroraPreparingOrchid,
    required this.auroraQuestionPeri,
    required this.auroraQuestionSky,
    required this.auroraQuestionIndigo,
    required this.auroraGeneratingMint,
    required this.auroraGeneratingCoral,
    required this.auroraGeneratingLemon,
    required this.auroraPlanetFade,
    required this.auroraRewardFade,
    required this.stageDone,
    required this.stagePending,
    required this.stagePendingText,
    required this.checkDone,
    required this.checkIdleBorder,
    required this.rewardBadgeTop,
    required this.rewardBadgeBottom,
    required this.rewardEmptyLabel,
    required this.consentCheckIdle,
    required this.roleElumi,
    required this.checkPending,
    required this.rewardBackdropTop,
    required this.rewardBackdropBottom,
    required this.routineDoneBackdropBottom,
    required this.rewardStar,
    required this.rewardStarGlow,
    required this.rewardStarHalo,
    required this.rewardStarGreen,
    required this.rewardStarPurple,
    required this.starDecoGlowGreen,
    required this.starDecoGlowPurple,
    required this.rewardButton,
    required this.rewardGroundShadow,
    required this.childEmptyShadow,
    required this.characterCardShadow,
    required this.routineTileBg,
    required this.routineRingTrack,
    required this.routineRingProgress,
    required this.routineTileSwiped,
    required this.routineSwipeDelete,
    required this.routineSwipeEdit,
    required this.routineTileLabel,
    required this.routineTileReward,
    required this.routineDragHandle,
    required this.routineCreateStart,
    required this.routineCreateEnd,
    required this.routineCreateGlow,
    required this.routineEmptyHint,
    required this.childTileDone,
    required this.starCount,
    required this.rewardChipHighlight,
    required this.coachScrim,
    required this.coachAccent,
    required this.coachText,
    required this.starsNumberStart,
    required this.editChipBg,
    required this.editChipLabel,
    required this.topBarActionText,
    required this.sheetFieldLabelText,
    required this.sheetScrim,
    required this.dialogScrim,
    required this.rewardLineLead,
    required this.editChipPressedBg,
    required this.tabletSceneSkyTop,
    required this.tabletSceneSkyBottom,
    required this.tabletSceneHillBack,
    required this.tabletSceneHillFront,
    required this.tabletSceneCloud,
    required this.tabletSceneSparkle,
    required this.nightSkyTwinkle,
    required this.stepStripGoalFill,
    required this.stepStripGoalBorder,
    required this.tabletSceneGroundShadow,
    required this.loginKakaoBg,
    required this.loginKakaoLabel,
    required this.loginNaverBg,
    required this.loginNaverLabel,
    required this.glassFill,
    required this.glassBorder,
    required this.rewardBannerBg,
    required this.linkTimer,
    required this.linkRetryChipBg,
    required this.linkLaterLabel,
    required this.loginButtonShadow,
    required this.loginAppleBg,
    required this.loginLastUsedBg,
    required this.settingsDestructive,
    required this.settingsChevron,
    required this.settingsCardLabel,
    required this.settingsCardValue,
    required this.myInfoMetaText,
    required this.myInfoMutedIcon,
    required this.settingsToggleOn,
    required this.settingsToggleOff,
    required this.settingsGroupBg,
    required this.settingsGroupDivider,
    required this.settingsGroupLabel,
    required this.segmentedTabAccent,
    required this.segmentedTabUnselectedLabel,
    required this.peopleMeBadgeBg,
    required this.peopleMeBadgeText,
    required this.peopleGuardianChipBg,
    required this.peopleGuardianChipText,
    required this.peopleCaregiverChipBg,
    required this.peopleCaregiverChipText,
    required this.peopleRowBg,
    required this.peopleTextPrimary,
    required this.peopleTextSecondary,
    required this.peopleGuardianChipBorder,
    required this.peopleCaregiverChipBorder,
    required this.peopleChevron,
    required this.peopleEditPlaceholder,
    required this.peopleEditChipIdleText,
    required this.cardPhotoSlotDash,
    required this.creditCardBg,
    required this.creditBarTrack,
    required this.creditBarFill,
    required this.creditDivider,
    required this.creditAccentText,
    required this.creditNoticeBg,
    required this.creditNumberText,
    required this.creditMutedText,
    required this.creditHistoryMutedText,
    required this.notificationIconBackground,
    required this.notificationIconForeground,
    required this.notificationUnreadDot,
    required this.notificationRowText,
    required this.notificationMutedText,
    required this.notificationPermissionBannerBg,
    required this.notificationBellIcon,
    required this.notificationBellUnreadDot,
    required this.notificationBellUnreadDotBorder,
    required this.loginAppleLabel,
    required this.consentSelectedFill,
    required this.consentSelectedBorder,
    required this.dlpBadgeText,
    required this.homeHeroStart,
    required this.homeHeroEnd,
    required this.completionBgTop,
    required this.completionBgBottom,
    required this.completionInk,
    required this.completionSubtle,
    required this.stepBadge1,
    required this.stepBadge2,
    required this.stepBadge3,
    required this.stepBadge4,
    required this.noticeImagePlaceholder,
    required this.noticeHideLabel,
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

  // 보조 버튼 — 누를 수 있지만 권하지는 않는 쪽(확인 시트의 '취소' 등).
  // buttonDisabled를 쓰면 "못 누르는 버튼"으로 읽혀 취소가 막힌 것처럼 보인다.
  final Color buttonNeutral;
  final Color buttonNeutralText;

  // 팝업 전용. `buttonNeutral`·`danger`와 값이 달라서가 아니라 **쓰임이 달라서**
  // 나눈다 — 저 둘은 설정의 되돌릴 수 없는 항목, 연결 암호 오류, 설정 시트 버튼도
  // 함께 쓴다. 팝업을 시안에 맞추려고 저 토큰을 건드리면 그 셋까지 같이 바뀐다.
  /// 바텀시트 맨 위 손잡이 (시안 980:4893 · stroke #CACACA · 40×4).
  ///
  /// **`border`(#EFEFEF)를 쓰면 안 된다.** 시트 배경이 #F7F2EF 라 거의 같은 색이
  /// 되어 손잡이가 통째로 안 보인다. 실제로 그렇게 두어 "상단이 시안과 다르다"는
  /// 지적을 받았다.
  final Color sheetHandle;

  /// 시트 제목. 앱 본문색이 아니라 시안(980:4892) 그대로 순검정이다.
  final Color sheetTitleText;

  /// 팝업 제목. 앱 본문색(#242634)이 아니라 시안 그대로 순검정이다.
  final Color dialogTitleText;

  /// 팝업의 보조 버튼(취소). 진회색 바탕에 **흰 글자**다.
  final Color dialogNeutral;
  final Color dialogNeutralText;

  /// 팝업의 되돌릴 수 없는 버튼(삭제). 타일을 밀었을 때 나오는 삭제 버튼과 같은 빨강 —
  /// 같은 "삭제"인데 빨강이 두 가지면 같은 뜻으로 읽히지 않는다.
  final Color dialogDanger;

  // 되돌릴 수 없는 동작. 흐리게가 아니라 이 색으로 알린다 —
  // 흐린 색은 위험이 아니라 비활성으로 읽힌다.
  // 시안 위험색 #DA5050 하나 (회원탈퇴 글자 · 삭제 팝업 버튼 · 실패 팝업). 바탕 대비 3.9:1 이라 13 이하 글자에는 쓰지 않는다
  final Color danger;
  final Color dangerText;

  // 강조 표면 — 보호자 화면의 마스킹 결과·요약 배지 등.
  // Figma 명세가 없는 임시 값이다. 디자인이 확정되면 교체한다.
  final Color highlightFill;
  final Color highlightBorder;

  // 선택 상태 — 용도마다 색이 다르다. 하나로 묶으면 표현이 불가능하다.
  // 목표 칩 (Figma 온보딩_목표_선택 204:1147)
  final Color goalSelectedFill;
  final Color goalSelectedBorder;

  // 일과 관리 격자의 `새 일과` 칸 테두리 (시안 1931:6923, #93DBCC 2px). 값이 goalSelectedBorder 와 같아도 쓰임이 달라 따로 둔다
  final Color libraryNewOutline;

  // 가져온 일과 상세의 출처 띠 — 웜그레이 판 + 남색 글자 (안내 판 결)
  // 테두리·아이콘 원은 goalSelectedBorder 를 쓴다
  final Color talkOriginBandFill;
  final Color talkOriginBandAction;

  // 이야기 피드 카드 (시안 1783:6640)
  /// 흰 카드·그림 칸 1px 테두리 (#EEE9E6)
  final Color talkCardBorder;
  /// 섹션 제목·카드 제목·분류 글자 (#000000 — 본문색 #242634 와 다르다)
  final Color talkTitleText;
  /// 시간·한마디·숫자·작성자 (#74757D)
  final Color talkMetaText;
  /// 도움돼요·댓글·가져감 10px 아이콘 (#CACACA)
  final Color talkMetaIcon;
  /// 인기 카드 판 (#EEE9E6, 테두리 없음 — 시안 1783:6666)
  final Color talkPopularCardFill;
  /// 글 정보 사이 세로선 (#D9D3CF): 이야기 상세 작성자 | 시각 (시안 1813:7491), 홈 일과 줄 보상 | 만든 사람 (931:3896)
  final Color metaDivider;
  /// 상세 본문 | 댓글 사이 화면 폭 띠 (#EEE9E6 · 높이 7, 시안 1830:7918)
  final Color talkSectionDivider;

  /// 고르기 줄 · 칩을 고른 판 (민트 연 #B5EAEC, 시안 1869:8959 고름 결)
  final Color talkChoiceSelectedFill;

  /// 고르기 줄을 고른 테두리 (민트 1px, 시안 1869:8959)
  final Color talkChoiceSelectedBorder;

  /// 고르기 줄 빈 동그라미 테두리 (웜그레이 선)
  final Color talkChoiceRadioBorder;

  /// 고른 점 · 켠 체크 · 댓글 보내기 · 커서 (민트 #55CFBA, 시안 1860:8085)
  final Color talkAccentText;

  /// 규칙 · 빈 상태 안내를 담는 웜그레이 판
  final Color talkPanelFill;

  /// 이야기 댓글 칸 바탕 (시안 1860:7944)
  final Color talkCommentFill;

  /// 내가 쓴 댓글의 이름 (시안 1860:7930)
  final Color talkCommentMineName;

  /// 가져오기 시트에서 고른 묶음 칸 바탕 · 테두리 (시안 1869:8959)
  final Color talkImportGroupSelectedFill;
  final Color talkImportGroupSelectedStroke;

  /// 댓글 입력칸 판 (흰색 60%, 시안 1806:7485)
  final Color talkCommentFieldFill;

  /// 사진 고르기 칸 판 (#EEE9E6, 시안 1877:10569)
  final Color talkBlurChoicePanelFill;

  /// `흐리게` · `그대로` 고른 버튼 (#242634, 시안 1877:10589)
  final Color talkBlurChoiceSelectedFill;

  /// `흐리게` · `그대로` 안 고른 버튼 (#D7D3D1, 시안 1877:10591)
  final Color talkBlurChoiceFill;

  /// `흐리게` · `그대로` 버튼 글자 (고름 · 안 고름 모두 흰색)
  final Color talkBlurChoiceLabel;

  /// 한마디 입력 글자 (#000000, 시안 1870:9545)
  final Color talkNoteText;

  /// 한마디 입력칸 안내 글자 (#242634 40%, 시안 1870:9451)
  final Color talkNoteHint;



  // 캐릭터 카드는 캐릭터마다 다르다
  // (Figma 온보딩_캐릭터_여우 204:1121 / 온보딩_캐릭터_고양이 204:1134)
  final Color foxSelectedFill;
  final Color foxSelectedBorder;
  final Color catSelectedFill;
  final Color catSelectedBorder;

  final Color brandPeach;

  /// 포포(여우) 그림 주황 — 축하 색종이(confetti)에만. UI 강조 · 선택 · 크레딧에 쓰지 않는다 (시안 UI 에 없는 색)
  final Color brandOrange;

  /// 별 보상
  final Color accentYellow;

  // 시작·로그인 화면
  /// 시작 화면의 **단색** 배경 (Figma `스플래시` 1022:4415).
  ///
  /// 값이 [splashBottom]과 같지만 따로 둔다 — 시작 화면은 단색 한 장이고
  /// 로그인 화면은 그라데이션이라, 한쪽만 바뀔 수 있다.
  final Color splashPlain;

  /// 로그인 화면 배경 그라데이션 시작색 (Figma `로그인_iOS` 238:1808)
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

  /// 보호자 하단 바·옆 메뉴 바탕 (시안 1666:7082, #835)
  final Color navBackground;

  /// 하단 바 위 선·옆 메뉴 오른쪽 선 2px (시안 1666:7082, #835)
  final Color navDivider;

  /// 고른 칸 아이콘·글자 (#798)
  final Color navIconSelected;

  /// 고르지 않은 칸 아이콘·글자 (남색 20%, 하단 바 시안 1666:7082와 같은 값) (#798)
  final Color navIconUnselected;

  /// 옆 메뉴 고른 칸 바탕 (웜그레이 판 #EEE9E6 — 시안 판 색) (#798)
  final Color navSelectedFill;

  /// 하단 바 · 옆 메뉴 고르지 않은 칸 아이콘·글자 (#242634 20%, 시안 1666:7082, #835). 고른 칸은 navIconSelected
  final Color navItemUnselected;

  /// 일과관리 묶음(폴더) 칸 바탕 (#DDD9D9, 시안 1664:6876 회색 2x2 폴더)
  final Color folderFill;

  /// 일과관리 묶음 칸 테두리 1px 안쪽 (#BFBDBD, 시안 1664:6876)
  final Color folderStroke;

  /// 일과관리 칸 이름 (#000000, 시안 1664:6876 — 본문색 #242634 와 다르다)
  final Color libraryTileLabel;

  /// 같은 카드의 그림자 (Figma 0px 4px 10px rgba(35,13,96,0.1))
  final Color homeCardShadow;

  /// 같은 카드의 아이콘 원형 배경 (Figma 217:2668, rgba(130,220,223,0.4))
  final Color homeCardIconBg;

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

  // 보상 설정(Figma 1082:4709) 배경 — 입력 화면과 **같은 두 원을 색만 바꿔** 그렸다.
  // 세 값은 위 민트·보라·노랑과 같은 자리(Eclipse 시작 · Eclipse 끝 · Planet 시작)다.
  // 자리가 같아야 두 화면 사이에서 색만 번지고 모양은 그대로 남는다.

  /// 보상 배경 — 보라 (Eclipse 시작 #A97BFF)
  final Color auroraRewardViolet;

  /// 보상 배경 — 분홍 (Eclipse 끝 #FF6FB9)
  final Color auroraRewardPink;

  /// 보상 배경 — 장미 (Planet 시작 #FB8BD4)
  final Color auroraRewardRose;

  // 로딩·추가질문(Figma 262:4569 · 262:4766 · 262:4703) 배경 — 입력·보상과 같은 두 원을
  // 색만 바꿔 그렸다. 자리는 위 셋과 같다
  // (Eclipse 시작 · Eclipse 끝 · Planet 시작).

  /// 준비 로딩 배경 — 안개 (Eclipse 단색 #CED8FF — 시작·끝이 같다)
  final Color auroraPreparingHaze;

  /// 준비 로딩 배경 — 난초 (Planet 시작 #CB51FC)
  final Color auroraPreparingOrchid;

  /// 추가질문 배경 — 연보라 (Eclipse 시작 #A7AAFF)
  final Color auroraQuestionPeri;

  /// 추가질문 배경 — 하늘 (Eclipse 끝 #6FC5FF)
  final Color auroraQuestionSky;

  /// 추가질문 배경 — 남보라 (Planet 시작 #5651FC)
  final Color auroraQuestionIndigo;

  /// 생성 로딩 배경 — 연두 (Eclipse 시작 #7BFFB0)
  final Color auroraGeneratingMint;

  /// 생성 로딩 배경 — 산호 (Eclipse 끝 #FF6F93)
  final Color auroraGeneratingCoral;

  /// 생성 로딩 배경 — 레몬 (Planet 시작 #FCF351)
  final Color auroraGeneratingLemon;

  /// Planet 원 아래 끝 — 투명 하늘 (#3CFFFF 0%). 보상만 빼고 모두 이 값이다
  final Color auroraPlanetFade;

  /// 보상 배경 Planet 아래 끝 — 투명 진분홍 (#FF3CA1 0%). 보상만 하늘이 아니다
  final Color auroraRewardFade;

  /// 로딩 완료 단계 — 채운 원·진한 문구 (rgba(36,38,52,0.8))
  final Color stageDone;

  /// 로딩 대기 단계 — 빈 원 테두리 (rgba(36,38,52,0.6))
  final Color stagePending;

  /// 로딩 대기 단계 문구 (rgba(36,38,52,0.5))
  final Color stagePendingText;

  // 아이 모드 (Figma 309:3548 / 309:4055)
  /// 아이 홈 체크 완료 원
  final Color checkDone;

  /// 아직 체크하지 않은 동그라미의 테두리 (Figma `채크_라운드` Default — #C9D6D4).
  ///
  /// 공통 `border`(#EFEFEF)를 쓰지 않는다. 시안이 이 동그라미에만 청록기가 도는
  /// 테두리를 줬고, 공통 테두리로 칠하면 카드 경계와 구분되지 않는다.
  final Color checkIdleBorder;

  /// 일과 시트 보상 뱃지의 그라데이션 (Figma `963:4424` — 180deg #0C0D1A → #242634).
  ///
  /// 아래쪽 값이 `textPrimary`와 같지만 나눠 둔다. 글자색이 바뀐다고 뱃지까지
  /// 따라가면 안 된다.
  final Color rewardBadgeTop;
  final Color rewardBadgeBottom;

  /// 보상을 아직 정하지 않았을 때의 안내 글자 (Figma `980:5183` — #AEB0B7).
  ///
  /// `textSecondary`보다 흐리다. 채워진 내용이 아니라 **비어 있음**을 말하는
  /// 자리라서, 정해진 보상과 같은 굵기로 보이면 안 된다.
  final Color rewardEmptyLabel;

  /// 약관 항목의 아직 안 누른 체크 (Figma 739:3747 실측 #C9D6D4 · 이슈 #226).
  ///
  /// `border`(#EFEFEF)를 쓰면 배경(#F7F2EF)과 거의 같아 **원이 안 보인다.**
  /// 눌러야 하는 자리가 안 보이면 무엇을 해야 하는지 알 수 없다.
  final Color consentCheckIdle;

  /// 역할 선택에서 `이룸이`를 가리키는 색 (Figma 732:5258 실측 #FFAA00 · 이슈 #229).
  ///
  /// `보호자`는 포인트색(`checkDone`)을 쓰고 `이룸이`는 주황이다. 두 선택지를
  /// **색으로 먼저 구분**하게 한다 — 글을 빨리 읽지 못해도 어느 쪽이 자기인지 보인다.
  final Color roleElumi;

  /// 아이 홈 체크 전 테두리 (8px)
  final Color checkPending;

  /// 보상 화면 배경 위 (어두워야 별이 빛난다)
  final Color rewardBackdropTop;

  /// 보상 화면 배경 아래
  final Color rewardBackdropBottom;

  /// 일과완료 화면 배경 아래 끝색 (Figma 1274:9831, 위 끝은 [rewardBackdropTop]).
  final Color routineDoneBackdropBottom;

  /// 보상 큰 별
  final Color rewardStar;

  /// 큰 별 주변 빛 (rgba(208,255,0,0.3))
  final Color rewardStarGlow;

  /// 큰 별 뒤 넓게 번지는 blur 후광 — 노랑 (#FFDD00). Figma의 blur(20px) 노란 별 레이어.
  final Color rewardStarHalo;

  /// 작은 별 — 초록
  final Color rewardStarGreen;

  /// 작은 별 — 보라
  final Color rewardStarPurple;

  /// 작은 별 주변 빛 — 초록 (rgba(123,255,176,1)). star_deco 1~6의 SVG
  /// 내장 feGaussianBlur 필터 색과 동일 — flutter_svg가 SVG filter를
  /// 렌더링하지 못해(client/docs/troubleshooting.md) 코드로 재현한다.
  final Color starDecoGlowGreen;

  /// 작은 별 주변 빛 — 보라 (rgba(151,120,255,1)). star_deco 7 전용.
  final Color starDecoGlowPurple;

  /// 보상 화면 CTA
  final Color rewardButton;

  /// 보상 캐릭터 발밑 그림자 (Figma Ellipse 23 — 어두운 배경용)
  final Color rewardGroundShadow;

  /// 아이 홈 빈 상태 캐릭터 발밑 그림자 (Figma Ellipse 2 — 밝은 배경용).
  /// 보상 화면 그림자와 배경이 달라 항상 따로 바뀐다 — 토큰을 나눈다.
  final Color childEmptyShadow;

  /// 온보딩 캐릭터 카드 안 발밑 그림자 (Figma `204:1037` 그림자 — 흰 카드 위).
  /// [childEmptyShadow]와 값은 같지만 바탕이 다르다(흰 카드 vs 베이지 화면) —
  /// 한쪽만 조정될 수 있으므로 묶지 않는다.
  final Color characterCardShadow;

  // 홈 일과 목록 (Figma 356:4688 / 309:3739 / 356:5079)
  /// 일과 타일·펼침 컨테이너·빈 상태 배경 (#EEE9E6)
  final Color routineTileBg;

  /// 진행률 링 트랙. checkPending과 값이 같지만(#C9D6D4) 쓰임이 달라 분리 —
  /// 아이 체크 버튼 테두리가 바뀌어도 링 트랙은 따라가면 안 된다.
  final Color routineRingTrack;

  /// 진행률 링 채움·퍼센트 문구. checkDone(#55CFBA)과 분리, 같은 이유.
  final Color routineRingProgress;

  /// 밀어서 열린 / 순서 바꾸는 중인 일과 카드 배경 (#D7D3D1).
  /// 기본 배경(routineTileBg)보다 한 단계 어둡다 — 지금 손대고 있는 카드가 어느 것인지
  /// 색으로 드러나야 옆의 버튼이 누구 것인지 헷갈리지 않는다.
  final Color routineTileSwiped;

  /// 밀었을 때 나오는 삭제 버튼 배경 (#DA5050). linkTimer와 값만 같다 —
  /// 남은 시간 색이 바뀌어도 삭제 버튼이 따라가면 안 된다.
  final Color routineSwipeDelete;

  /// 밀었을 때 나오는 수정 버튼 배경 (#F8C905).
  final Color routineSwipeEdit;

  /// 일과 카드의 `완료 시` 라벨과 섹션 제목 (#74757D).
  final Color routineTileLabel;

  /// 보상 문구 rgba(0,0,0,0.7). 제목보다 옅고 라벨보다 진하다 —
  /// 셋이 한 줄에 서므로 무게가 겹치면 어느 것이 값인지 읽히지 않는다.
  final Color routineTileReward;

  /// 순서 바꾸기 손잡이 (#CACACA).
  final Color routineDragHandle;

  /// `새로운 일과 만들기` 버튼 방사형 그라데이션 가운데 (#A2B1EB).
  final Color routineCreateStart;

  /// 같은 버튼 방사형 그라데이션 바깥 (#9C7DE9).
  final Color routineCreateEnd;

  /// 같은 버튼 바깥으로 번지는 빛 (#CCBCF6). 그림자가 아니라 발광이라 흐림이 크고 색이 진하다.
  final Color routineCreateGlow;

  /// 빈 상태 둘째 줄 (#AEB0B7). 제목(routineTileLabel #74757D)보다 한 단계 더 옅다 —
  /// 할 일이 없다는 자리라 두 줄이 같은 무게로 읽히면 안 된다.
  final Color routineEmptyHint;

  /// 아이 홈 완료된 일과 타일 배경 (#B5EAEC). goalSelectedFill과 값만 같다.
  final Color childTileDone;

  /// 별 배지 숫자 (#CB9500)
  final Color starCount;

  /// 밝은 화면 보상 칩에서 보상 글자 (#40BBA6). 시안 PNG 실측 — Figma 덤프에는
  /// 글자 구간별 색이 오지 않아 `다하면`과 한 색으로 보인다. 어두운 화면은 checkDone(#55CFBA).
  final Color rewardChipHighlight;

  /// 코치마크 막 (검정 75%, 시안 1274:10393). 구멍 밖 화면을 덮는다.
  final Color coachScrim;

  /// 코치마크 말풍선의 강조 글자 (#55CFBA, 시안 1274:10400 실측).
  final Color coachAccent;

  /// 코치마크 말풍선의 기본 글자 (흰색, 시안 1274:10400).
  final Color coachText;

  /// 아이_별 화면 숫자 그라데이션 시작 (#FFDD00 → 흰색)
  final Color starsNumberStart;

  // 카드확인 (Figma 262:5124)
  /// `이 카드 수정하기` 칩 배경 (#EEE9E6). routineTileBg와 값만 같다 —
  /// 일과 타일이 바뀌어도 수정 칩은 따라가면 안 된다.
  final Color editChipBg;

  /// 같은 칩의 문구색 (#000000). chipLabel(선택 항목)과 쓰임이 달라 분리한다.
  final Color editChipLabel;

  /// 상단바 오른쪽 `임시저장` 글자 (#74757D, 시안 1173:5591).
  final Color topBarActionText;

  /// 카드 수정·추가 시트의 `제목`·`설명` 라벨 (#74757D, 시안 1197:6027).
  final Color sheetFieldLabelText;

  /// 카드 수정·추가 시트 뒤 어두운 막 (rgba(0,0,0,0.5), 시안 1197:5923 Scrim).
  final Color sheetScrim;

  /// 팝업 뒤 어두운 막 (검정 50%): 공통 팝업·크레딧 대기·공지 팝업.
  final Color dialogScrim;

  /// 카드확인 보상 줄의 `완료 시` 부분 (#74757D, 시안 1173:5544). 뒤의 보상 이름은 textPrimary 라 회색/검정으로 갈린다.
  final Color rewardLineLead;

  /// 카드확인 도구 버튼이 눌린 상태의 배경 (#D7D3D1, 시안 1197:5798 순서 변경 모드의 `카드 순서 변경`). 다른 화면의 #D7D3D1 과 값만 같다.
  final Color editChipPressedBg;

  /// 태블릿 장면 그림 하늘 위 (#DDE6FF, 시안 없음 · #789 개발 제안)
  final Color tabletSceneSkyTop;

  /// 태블릿 장면 그림 하늘 아래 (#FFF4E6)
  final Color tabletSceneSkyBottom;

  /// 태블릿 장면 그림 뒤 언덕 (#D3EEDD)
  final Color tabletSceneHillBack;

  /// 태블릿 장면 그림 앞 언덕 (#B7E2C9)
  final Color tabletSceneHillFront;

  /// 태블릿 장면 그림 구름 (흰색 85%)
  final Color tabletSceneCloud;

  /// 태블릿 장면 그림 반짝이 별 (#FFD45C)
  final Color tabletSceneSparkle;

  /// 태블릿 밤하늘 별 밭의 작은 별 (흰색 90%)
  final Color nightSkyTwinkle;

  /// 태블릿 카드 순서 줄 끝 보상 칸 바탕 (#FFF3D6)
  final Color stepStripGoalFill;

  /// 태블릿 카드 순서 줄 끝 보상 칸 테두리 (#FFCF70)
  final Color stepStripGoalBorder;

  /// 태블릿 장면 그림 캐릭터 발밑 그림자 (#2E5A43 12%)
  final Color tabletSceneGroundShadow;

  // --- 소셜 로그인 버튼 ---
  //
  // 각 제공자가 정한 **브랜드 고정값**이다. 디자이너가 바꾸는 값이 아니며,
  // 임의로 손대면 제공자 검수·스토어 심사에서 지적받는다.
  // 그래도 토큰으로 두는 이유는 화면에서 Color(0x...)를 직접 쓰지 않기로 한
  // 규칙(design_token_test)을 예외 없이 지키기 위해서다.
  final Color loginKakaoBg;
  final Color loginKakaoLabel;
  final Color loginNaverBg;
  final Color loginNaverLabel;

  /// 반투명 유리 면 — 배경 그라데이션 위에 얹는 입력칸·카드.
  ///
  /// 불투명한 흰 상자를 올리면 뒤 배경이 잘려 화면이 두 조각으로 보인다.
  /// 반투명으로 두면 색이 비쳐 한 장면으로 이어진다.
  final Color glassFill;

  /// 유리 면의 테두리. 면보다 밝아야 가장자리가 잡힌다.
  final Color glassBorder;

  /// 이룸이 화면 보상 배너 배경.
  ///
  /// 카드보다 물러나야 한다 — 보상이 주인공이 되면 지금 할 일을 가린다.
  final Color rewardBannerBg;

  /// 연결 암호 남은 시간 (#DA5050).
  ///
  /// `danger` 와 값은 같지만 쓰임이 다르다. 저쪽은 되돌릴 수 없는 동작,
  /// 이건 "시간이 간다"를 알리는 표시다. 합치면 한쪽만 못 바꾼다.
  final Color linkTimer;

  /// `코드 다시 만들기` 칩 배경 (#EEE9E6).
  final Color linkRetryChipBg;

  /// `나중에 할게요` 글자 (#74757D).
  final Color linkLaterLabel;

  /// 제공자 버튼 그림자 (시안 4,4 blur 6 · 검정 5%).
  final Color loginButtonShadow;
  final Color loginAppleBg;
  final Color loginAppleLabel;

  /// `최근 로그인` 알약 배경 (Figma `238:1808` — #FFFADC 투명도 50%).
  ///
  /// 버튼 위에 겹쳐 놓기 때문에 반투명이다. 불투명하게 두면 버튼 색이 비치지
  /// 않아 세 제공자에서 모두 같은 크림색 알약으로 보인다.
  final Color loginLastUsedBg;

  /// 설정의 `회원탈퇴` 글자 (Figma `1022:4467` — #DA5050).
  ///
  /// `danger` 와 값은 같지만(시안 위험색은 #DA5050 하나) 글자 쪽 쓰임이라 나눈다.
  final Color settingsDestructive;

  /// 설정 목록의 오른쪽 화살표 (Figma `fi-br-angle-small` #CACACA).
  final Color settingsChevron;

  /// 묶음 카드 설정 줄 글자 (Figma `1532:7501` — #000000). 본문색(`textPrimary`)과 값이 달라 나눈다.
  final Color settingsCardLabel;

  /// 묶음 카드 설정 줄 오른쪽 값 글자 (`그림 방식  실사`, `앱 정보  버전`).
  final Color settingsCardValue;

  /// 내 정보 닉네임 카드의 이메일·가입일 글자와 제목 줄 톱니 (Figma `1736:8780` #74757D).
  final Color myInfoMetaText;

  /// 내 정보 닉네임 카드의 연필·달력 아이콘 (Figma `1736:8780` #CACACA).
  final Color myInfoMutedIcon;

  /// 묶음 카드 설정 줄의 켜짐 토글 바탕.
  final Color settingsToggleOn;

  /// 묶음 카드 설정 줄의 꺼짐 토글 바탕 (#D7D3D1, 시안 1732:8563).
  final Color settingsToggleOff;

  // --- 설정 묶음 카드 (iOS inset grouped, 임시 시안 #645) ---

  /// 설정 줄을 묶는 흰 카드 바탕.
  final Color settingsGroupBg;

  /// 묶음 카드 안 줄 사이 가는 선.
  final Color settingsGroupDivider;

  /// 설정 묶음 머리 · 꼬리 글 (회색 #74757D, 시안 1589:8359 날짜 라벨 결)
  final Color settingsGroupLabel;

  /// 상단 탭 밑줄 · 안 읽음 점 (민트, 시안 1724:8346)
  final Color segmentedTabAccent;

  /// 상단 탭 안 고른 칸 글자 (회색, 시안 1724:8346)
  final Color segmentedTabUnselectedLabel;

  // --- 함께하는 사람 (시안 1027:4617 · 1532:6877 · 1532:7013) ---

  /// `나` 배지.
  final Color peopleMeBadgeBg;
  final Color peopleMeBadgeText;

  /// 홈 일과 타일의 `예시` 배지 — 온보딩 예시 일과 (#803).

  /// 구분 칩 `보호자`.
  final Color peopleGuardianChipBg;
  final Color peopleGuardianChipText;

  /// 구분 칩 `선생님`.
  final Color peopleCaregiverChipBg;
  final Color peopleCaregiverChipText;

  /// 사람 한 줄 카드 바탕.
  final Color peopleRowBg;

  /// 이름·초대 줄·시트 설명 글자.
  final Color peopleTextPrimary;

  /// 머리 설명·그만두기 보조 글자.
  final Color peopleTextSecondary;

  /// 구분 칩 `보호자` 테두리 (시트에서 고른 칩과 같다).
  final Color peopleGuardianChipBorder;

  /// 구분 칩 `선생님` 테두리 (시트에서 고른 칩과 같다).
  final Color peopleCaregiverChipBorder;

  /// 초대·그만두기 카드 오른쪽 꺾쇠.
  final Color peopleChevron;

  /// 이름 변경 시트 입력칸 예시 글 (검정 20%).
  final Color peopleEditPlaceholder;

  /// 이름 변경 시트에서 고르지 않은 구분 칩 글자 (검정 30%).
  final Color peopleEditChipIdleText;

  // --- 그림 방식 · 기본 카드 (임시 시안) ---
  // 값이 다른 토큰과 같아도(#DADADA 등) 쓰임이 달라 따로 둔다 — 시안이 확정되면
  // 이 자리들만 따로 바뀐다.

  /// 그림 없는 카드(보호자)의 `사진 추가` 점선 자리 테두리.
  final Color cardPhotoSlotDash;

  // --- AI 크레딧 ---

  /// AI 크레딧 카드 면 (흰 카드).
  final Color creditCardBg;

  /// 크레딧 막대의 빈 쪽.
  final Color creditBarTrack;

  /// 크레딧 막대의 남은 쪽 (Figma `1532:7501` — #BAA0F9).
  final Color creditBarFill;

  /// 크레딧 카드 안 구분선. 막대 빈 쪽과 값이 같지만 쓰임이 달라 나눈다.
  final Color creditDivider;

  /// 크레딧 카드 `다시 하기` 칩 글자 (남색, 웜그레이 칩 위)
  final Color creditAccentText;

  /// 크레딧 카드 `다시 하기` 칩 면 (웜그레이 #EEE9E6, `코드 다시 만들기` 칩과 같은 결)
  final Color creditNoticeBg;

  /// 크레딧 큰 숫자와 반짝임 (Figma `1532:7501` — #BAA0F9).
  final Color creditNumberText;

  /// 크레딧 카드의 보조 글자: 단위, 안내 아이콘, 다시 채워지는 날 (#9B97A4).
  final Color creditMutedText;

  /// 크레딧 사용 내역의 날짜·부제·줄어든 값 (Figma `1589:8359` `#74757D`).
  final Color creditHistoryMutedText;

  /// 알림 줄 왼쪽 둥근 네모 아이콘 바탕 (#AEE4D9, 시안 1724:8346)
  final Color notificationIconBackground;

  /// 알림 줄 아이콘 상자 안 그림 (#FFFFFF, 시안 1724:8346)
  final Color notificationIconForeground;

  /// 알림 줄 오른쪽 안 읽음 점 (#55CFBA, 시안 1724:8346)
  final Color notificationUnreadDot;

  /// 알림 줄 문장 (#000000, 시안 1724:8346). 본문색(`textPrimary`)과 값이 달라 나눈다.
  final Color notificationRowText;

  /// 알림 화면의 회색 글자·아이콘: 날짜 머리글, 시각, 톱니, 기기 알림 꺼짐 띠 (#74757D)
  final Color notificationMutedText;

  /// 알림 설정 맨 위 기기 알림 꺼짐 띠 바탕 (#EEE9E6, 시안 1732:8433)
  final Color notificationPermissionBannerBg;

  /// 머리 줄 종 아이콘 (Figma `alarm` 1724:7739 `#74757D`)
  final Color notificationBellIcon;

  /// 종 아이콘의 안 읽음 원 (Figma `alarm` `#55CFBA`)
  final Color notificationBellUnreadDot;

  /// 안 읽음 원 테두리 2. 종과 겹친 자리를 바탕색으로 끊어 보임 (Figma `#F7F2EF`)
  final Color notificationBellUnreadDotBorder;

  // --- 약관 동의 선택 상태 ---
  //
  // 값은 목표 칩 선택색과 같다. 그래도 토큰을 나누는 이유는 이 문서의 핵심 규칙
  // 때문이다 — 디자이너가 목표 칩 색만 바꿔도 동의 화면은 그대로여야 한다.
  final Color consentSelectedFill;
  final Color consentSelectedBorder;

  /// DLP 보안 배지 문구. 본문보다 물러나야 하지만 안내로는 읽혀야 한다
  /// (Figma Group 57/58).
  final Color dlpBadgeText;

  /// 보호자 홈 "새로운 일과 만들기" 카드 그라데이션 시작(왼쪽 노랑).
  final Color homeHeroStart;

  /// 같은 카드 그라데이션 끝(오른쪽 연보라).
  final Color homeHeroEnd;

  /// 카드 생성 완료 화면 배경 그라데이션 위(연두). Figma 425:4199.
  final Color completionBgTop;

  /// 같은 배경 그라데이션 아래(파랑).
  final Color completionBgBottom;

  /// 완료 화면의 글자·아이콘. 밝은 그라데이션 위라 본문색보다 진하다.
  final Color completionInk;

  /// 완료 화면의 보조 문구(진행도).
  final Color completionSubtle;

  /// 시트의 행동 단계 번호 뱃지. 네 색을 차례로 쓰고 다섯 번째부터 다시 처음으로
  /// 돌아간다 (Figma 956:4084). 단계가 몇 개든 색이 비지 않아야 한다.
  final Color stepBadge1;
  final Color stepBadge2;
  final Color stepBadge3;
  final Color stepBadge4;

  // --- 공지 팝업 (시안 `팝업` 1090:4922 `방침`) ---
  // 공통 팝업 컴포넌트의 변형이라 카드·버튼·제목·체크는 공통 팝업 토큰
  // (`surface`·`dialogNeutral`·`checkDone`·`dialogTitleText`·`checkIdleBorder`)을 그대로 쓴다.
  // 공통 팝업에 없는 자리 둘만 여기 둔다.

  /// 그림을 받는 동안의 그림 자리. 흰 카드 위 빈칸으로 보이지 않게 앱 배경색으로 채운다.
  /// **시안 밖이다** — 그림 있는 공지 변형은 디자이너 시안 전이라 임시로 둔다.
  /// `background`와 값만 같다 — 화면 배경이 바뀌어도 이 자리까지 따라갈 이유는 없다.
  final Color noticeImagePlaceholder;

  /// `일주일간 보지 않기` 글자 (시안 1090:4918 — #74757D).
  /// 제목·본문(순검정)보다 한 단계 흐리다. 누를 수 있지만 주 동작은 아니다.
  final Color noticeHideLabel;

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
    buttonNeutral: Color(0xFFEEE9E6),
    buttonNeutralText: Color(0xFF242634),
    // Figma 980:5146 `Frame 34` (시트 상단) 실측
    sheetHandle: Color(0xFFCACACA),
    sheetTitleText: Color(0xFF000000),
    // Figma 931:4878 `팝업` 컴포넌트셋 (variant 삭제) 실측
    dialogTitleText: Color(0xFF000000),
    dialogNeutral: Color(0xFFD7D3D1),
    dialogNeutralText: Color(0xFFFFFFFF),
    dialogDanger: Color(0xFFDA5050),
    // 팔레트의 코랄(#EB9B73)과 같은 난색 계열로 낮춰 잡았다. 배경 대비 4.7:1,
    // 흰 글씨 대비 5.4:1 — 작은 글씨에도 읽히면서 경고로 보인다.
    danger: Color(0xFFDA5050),
    dangerText: Color(0xFFFFFFFF),
    highlightFill: Color(0xFFFFDAC7),
    highlightBorder: Color(0xFFEB9B73),
    goalSelectedFill: Color(0xFFB5EAEC),
    goalSelectedBorder: Color(0xFF93DBCC),
    libraryNewOutline: Color(0xFF93DBCC),
    talkOriginBandFill: Color(0xFFEEE9E6),
    talkOriginBandAction: Color(0xFF242634),
    talkCardBorder: Color(0xFFEEE9E6),
    talkTitleText: Color(0xFF000000),
    talkMetaText: Color(0xFF74757D),
    talkMetaIcon: Color(0xFFCACACA),
    talkPopularCardFill: Color(0xFFEEE9E6),
    metaDivider: Color(0xFFD9D3CF),
    talkSectionDivider: Color(0xFFEEE9E6),
    talkChoiceSelectedFill: Color(0xFFB5EAEC),
    talkChoiceSelectedBorder: Color(0xFF55CFBA),
    talkChoiceRadioBorder: Color(0xFFD9D3CF),
    talkAccentText: Color(0xFF55CFBA),
    talkPanelFill: Color(0xFFEEE9E6),
    talkCommentFill: Color(0xFFEEE9E6),
    talkCommentMineName: Color(0xFF55CFBA),
    talkImportGroupSelectedFill: Color(0xFFB5EAEC),
    talkImportGroupSelectedStroke: Color(0xFF55CFBA),
    talkCommentFieldFill: Color(0x99FFFFFF),
    talkBlurChoicePanelFill: Color(0xFFEEE9E6),
    talkBlurChoiceSelectedFill: Color(0xFF242634),
    talkBlurChoiceFill: Color(0xFFD7D3D1),
    talkBlurChoiceLabel: Color(0xFFFFFFFF),
    talkNoteText: Color(0xFF000000),
    talkNoteHint: Color(0x66242634),
    foxSelectedFill: Color(0xFFFFDAC7),
    foxSelectedBorder: Color(0xFFEB9B73),
    catSelectedFill: Color(0xFFCED8FF),
    catSelectedBorder: Color(0xFF9CADF1),
    brandPeach: Color(0xFFFFC9BB),
    brandOrange: Color(0xFFFF8B22),
    accentYellow: Color(0xFFFFD629),
    splashPlain: Color(0xFFFFFADB),
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
    navBackground: Color(0xFFF7F2EF),
    navDivider: Color(0xFFEEE9E6),
    navIconSelected: Color(0xFF242634),
    navIconUnselected: Color(0x33242634),
    navSelectedFill: Color(0xFFEEE9E6),
    navItemUnselected: Color(0x33242634),
    folderFill: Color(0xFFDDD9D9),
    folderStroke: Color(0xFFBFBDBD),
    libraryTileLabel: Color(0xFF000000),
    homeCardShadow: Color(0x1A230D60), // rgba(35,13,96,0.1)
    homeCardIconBg: Color(0x6682DCDF), // rgba(130,220,223,0.4)
    glassSurface: Color(0x99FFFFFF), // rgba(255,255,255,0.6)
    glassChip: Color(0x80FFFFFF), // rgba(255,255,255,0.5)
    promptMuted: Color(0x66242634), // rgba(36,38,52,0.4)
    glassShadow: Color(0x0D000000),
    auroraMint: Color(0xFF7BFFE5),
    auroraViolet: Color(0xFFD16FFF),
    auroraYellow: Color(0xFFFCE551),
    auroraRewardViolet: Color(0xFFA97BFF),
    auroraRewardPink: Color(0xFFFF6FB9),
    auroraRewardRose: Color(0xFFFB8BD4),
    auroraPreparingHaze: Color(0xFFCED8FF),
    auroraPreparingOrchid: Color(0xFFCB51FC),
    auroraQuestionPeri: Color(0xFFA7AAFF),
    auroraQuestionSky: Color(0xFF6FC5FF),
    auroraQuestionIndigo: Color(0xFF5651FC),
    auroraGeneratingMint: Color(0xFF7BFFB0),
    auroraGeneratingCoral: Color(0xFFFF6F93),
    auroraGeneratingLemon: Color(0xFFFCF351),
    auroraPlanetFade: Color(0x003CFFFF),
    auroraRewardFade: Color(0x00FF3CA1),
    stageDone: Color(0xCC242634),
    stagePending: Color(0x99242634),
    stagePendingText: Color(0x80242634),
    checkDone: Color(0xFF55CFBA),
    checkIdleBorder: Color(0xFFC9D6D4),
    rewardBadgeTop: Color(0xFF0C0D1A),
    rewardBadgeBottom: Color(0xFF242634),
    rewardEmptyLabel: Color(0xFFAEB0B7),
    consentCheckIdle: Color(0xFFC9D6D4),
    roleElumi: Color(0xFFFFAA00),
    checkPending: Color(0xFFC9D6D4),
    rewardBackdropTop: Color(0xFF0C0D1A),
    rewardBackdropBottom: Color(0xFF242634),
    routineDoneBackdropBottom: Color(0xFF574D2B),
    rewardStar: Color(0xFFD0FF00),
    rewardStarGlow: Color(0x4DD0FF00),
    rewardStarHalo: Color(0xFFFFDD00),
    rewardStarGreen: Color(0xFF86FCA3),
    rewardStarPurple: Color(0xFFA186FC),
    starDecoGlowGreen: Color(0xFF7BFFB0),
    starDecoGlowPurple: Color(0xFF9778FF),
    rewardButton: Color(0xFF55CFBA),
    rewardGroundShadow: Color(0xFF121215),
    childEmptyShadow: Color(0x4D969696),
    characterCardShadow: Color(0x4D969696),
    routineTileBg: Color(0xFFEEE9E6),
    routineRingTrack: Color(0xFFC9D6D4),
    routineRingProgress: Color(0xFF55CFBA),
    routineTileSwiped: Color(0xFFD7D3D1),
    routineSwipeDelete: Color(0xFFDA5050),
    routineSwipeEdit: Color(0xFFF8C905),
    routineTileLabel: Color(0xFF74757D),
    routineTileReward: Color(0xB3000000),
    routineDragHandle: Color(0xFFCACACA),
    routineCreateStart: Color(0xFFA2B1EB),
    routineCreateEnd: Color(0xFF9C7DE9),
    routineCreateGlow: Color(0xFFCCBCF6),
    routineEmptyHint: Color(0xFFAEB0B7),
    childTileDone: Color(0xFFB5EAEC),
    starCount: Color(0xFFCB9500),
    rewardChipHighlight: Color(0xFF40BBA6),
    coachScrim: Color(0xBF000000),
    coachAccent: Color(0xFF55CFBA),
    coachText: Color(0xFFFFFFFF),
    starsNumberStart: Color(0xFFFFDD00),
    editChipBg: Color(0xFFEEE9E6),
    editChipLabel: Color(0xFF74757D),
    topBarActionText: Color(0xFF74757D),
    sheetFieldLabelText: Color(0xFF74757D),
    sheetScrim: Color(0x80000000),
    dialogScrim: Color.from(alpha: 0.5, red: 0, green: 0, blue: 0),
    rewardLineLead: Color(0xFF74757D),
    editChipPressedBg: Color(0xFFD7D3D1),
    tabletSceneSkyTop: Color(0xFFDDE6FF),
    tabletSceneSkyBottom: Color(0xFFFFF4E6),
    tabletSceneHillBack: Color(0xFFD3EEDD),
    tabletSceneHillFront: Color(0xFFB7E2C9),
    tabletSceneCloud: Color(0xD9FFFFFF),
    tabletSceneSparkle: Color(0xFFFFD45C),
    nightSkyTwinkle: Color(0xE6FFFFFF),
    stepStripGoalFill: Color(0xFFFFF3D6),
    stepStripGoalBorder: Color(0xFFFFCF70),
    tabletSceneGroundShadow: Color(0x1F2E5A43),
    loginKakaoBg: Color(0xFFFEE500),
    loginKakaoLabel: Color(0xFF191600),
    loginNaverBg: Color(0xFF03C75A),
    loginNaverLabel: Color(0xFFFFFFFF),
    glassFill: Color(0x8CFFFFFF),
    glassBorder: Color(0xB3FFFFFF),
    rewardBannerBg: Color(0xFFFFF3D6),
    linkTimer: Color(0xFFDA5050),
    linkRetryChipBg: Color(0xFFEEE9E6),
    linkLaterLabel: Color(0xFF74757D),
    loginButtonShadow: Color(0x0D000000),
    loginAppleBg: Color(0xFF000000),
    loginAppleLabel: Color(0xFFFFFFFF),
    loginLastUsedBg: Color(0x80FFFADC),
    settingsDestructive: Color(0xFFDA5050),
    settingsChevron: Color(0xFFCACACA),
    settingsCardLabel: Color(0xFF000000),
    settingsCardValue: Color(0xFF74757D),
    myInfoMetaText: Color(0xFF74757D),
    myInfoMutedIcon: Color(0xFFCACACA),
    settingsToggleOn: Color(0xFF55CFBA),
    settingsToggleOff: Color(0xFFD7D3D1),
    settingsGroupBg: Color(0xFFFFFFFF),
    settingsGroupDivider: Color(0xFFEFEFEF),
    settingsGroupLabel: Color(0xFF74757D),
    segmentedTabAccent: Color(0xFF55CFBA),
    segmentedTabUnselectedLabel: Color(0xFF74757D),
    peopleMeBadgeBg: Color(0xFFD7D3D1),
    peopleMeBadgeText: Color(0xFFFFFFFF),
    // 녹색 계열 연한 배지 — 상태(완료·진행)와 겹치지 않는 보조 표시
    peopleGuardianChipBg: Color(0xFFB5EAEC),
    peopleGuardianChipText: Color(0xFF388E7C),
    peopleCaregiverChipBg: Color(0xFFFFDAC7),
    peopleCaregiverChipText: Color(0xFFAC6744),
    peopleRowBg: Color(0xFFEEE9E6),
    peopleTextPrimary: Color(0xFF000000),
    peopleTextSecondary: Color(0xFF74757D),
    peopleGuardianChipBorder: Color(0xFF93DBCC),
    peopleCaregiverChipBorder: Color(0xFFF9C6AD),
    peopleChevron: Color(0xFFCACACA),
    peopleEditPlaceholder: Color(0x33000000),
    peopleEditChipIdleText: Color(0x4D000000),
    cardPhotoSlotDash: Color(0xFFDADADA),
    creditCardBg: Color(0xFFFFFFFF),
    creditBarTrack: Color(0xFFEEE9E6),
    creditBarFill: Color(0xFFBAA0F9),
    creditDivider: Color(0xFFEFEFEF),
    creditAccentText: Color(0xFF242634),
    creditNoticeBg: Color(0xFFEEE9E6),
    creditNumberText: Color(0xFFBAA0F9),
    creditMutedText: Color(0xFF9B97A4),
    creditHistoryMutedText: Color(0xFF74757D),
    notificationIconBackground: Color(0xFFAEE4D9),
    notificationIconForeground: Color(0xFFFFFFFF),
    notificationUnreadDot: Color(0xFF55CFBA),
    notificationRowText: Color(0xFF000000),
    notificationMutedText: Color(0xFF74757D),
    notificationPermissionBannerBg: Color(0xFFEEE9E6),
    notificationBellIcon: Color(0xFF74757D),
    notificationBellUnreadDot: Color(0xFF55CFBA),
    notificationBellUnreadDotBorder: Color(0xFFF7F2EF),
    consentSelectedFill: Color(0xFFB5EAEC),
    consentSelectedBorder: Color(0xFF93DBCC),
    dlpBadgeText: Color(0xFF74757D),
    homeHeroStart: Color(0xFFF9F1D7),
    homeHeroEnd: Color(0xFFE9EEFF),
    completionBgTop: Color(0xFF78FFB0),
    completionBgBottom: Color(0xFF0099FF),
    completionInk: Color(0xFF1A1A1A),
    completionSubtle: Color(0xFFA0A0A0),
    stepBadge1: Color(0xFFAEE4D9),
    stepBadge2: Color(0xFFB7C2EC),
    stepBadge3: Color(0xFFF4BDA2),
    stepBadge4: Color(0xFFECE0AE),
    noticeImagePlaceholder: Color(0xFFF7F2EF),
    noticeHideLabel: Color(0xFF74757D),
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
    Color? buttonNeutral,
    Color? buttonNeutralText,
    Color? sheetHandle,
    Color? sheetTitleText,
    Color? dialogTitleText,
    Color? dialogNeutral,
    Color? dialogNeutralText,
    Color? dialogDanger,
    Color? danger,
    Color? dangerText,
    Color? highlightFill,
    Color? highlightBorder,
    Color? goalSelectedFill,
    Color? goalSelectedBorder,
    Color? libraryNewOutline,
    Color? talkOriginBandFill,
    Color? talkOriginBandAction,
    Color? talkCardBorder,
    Color? talkTitleText,
    Color? talkMetaText,
    Color? talkMetaIcon,
    Color? talkPopularCardFill,
    Color? metaDivider,
    Color? talkSectionDivider,
    Color? talkChoiceSelectedFill,
    Color? talkChoiceSelectedBorder,
    Color? talkChoiceRadioBorder,
    Color? talkAccentText,
    Color? talkPanelFill,
    Color? talkCommentFill,
    Color? talkCommentMineName,
    Color? talkImportGroupSelectedFill,
    Color? talkImportGroupSelectedStroke,
    Color? talkCommentFieldFill,
    Color? talkBlurChoicePanelFill,
    Color? talkBlurChoiceSelectedFill,
    Color? talkBlurChoiceFill,
    Color? talkBlurChoiceLabel,
    Color? talkNoteText,
    Color? talkNoteHint,
    Color? foxSelectedFill,
    Color? foxSelectedBorder,
    Color? catSelectedFill,
    Color? catSelectedBorder,
    Color? brandPeach,
    Color? brandOrange,
    Color? accentYellow,
    Color? splashPlain,
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
    Color? navBackground,
    Color? navDivider,
    Color? navIconSelected,
    Color? navIconUnselected,
    Color? navSelectedFill,
    Color? navItemUnselected,
    Color? folderFill,
    Color? folderStroke,
    Color? libraryTileLabel,
    Color? homeCardShadow,
    Color? homeCardIconBg,
    Color? glassSurface,
    Color? glassChip,
    Color? promptMuted,
    Color? glassShadow,
    Color? auroraMint,
    Color? auroraViolet,
    Color? auroraYellow,
    Color? auroraRewardViolet,
    Color? auroraRewardPink,
    Color? auroraRewardRose,
    Color? auroraPreparingHaze,
    Color? auroraPreparingOrchid,
    Color? auroraQuestionPeri,
    Color? auroraQuestionSky,
    Color? auroraQuestionIndigo,
    Color? auroraGeneratingMint,
    Color? auroraGeneratingCoral,
    Color? auroraGeneratingLemon,
    Color? auroraPlanetFade,
    Color? auroraRewardFade,
    Color? stageDone,
    Color? stagePending,
    Color? stagePendingText,
    Color? checkDone,
    Color? checkIdleBorder,
    Color? rewardBadgeTop,
    Color? rewardBadgeBottom,
    Color? rewardEmptyLabel,
    Color? consentCheckIdle,
    Color? roleElumi,
    Color? checkPending,
    Color? rewardBackdropTop,
    Color? rewardBackdropBottom,
    Color? routineDoneBackdropBottom,
    Color? rewardStar,
    Color? rewardStarGlow,
    Color? rewardStarHalo,
    Color? rewardStarGreen,
    Color? rewardStarPurple,
    Color? starDecoGlowGreen,
    Color? starDecoGlowPurple,
    Color? rewardButton,
    Color? rewardGroundShadow,
    Color? childEmptyShadow,
    Color? characterCardShadow,
    Color? routineTileBg,
    Color? routineRingTrack,
    Color? routineRingProgress,
    Color? routineTileSwiped,
    Color? routineSwipeDelete,
    Color? routineSwipeEdit,
    Color? routineTileLabel,
    Color? routineTileReward,
    Color? routineDragHandle,
    Color? routineCreateStart,
    Color? routineCreateEnd,
    Color? routineCreateGlow,
    Color? routineEmptyHint,
    Color? childTileDone,
    Color? starCount,
    Color? rewardChipHighlight,
    Color? coachScrim,
    Color? coachAccent,
    Color? coachText,
    Color? starsNumberStart,
    Color? editChipBg,
    Color? editChipLabel,
    Color? topBarActionText,
    Color? sheetFieldLabelText,
    Color? sheetScrim,
    Color? dialogScrim,
    Color? rewardLineLead,
    Color? editChipPressedBg,
    Color? tabletSceneSkyTop,
    Color? tabletSceneSkyBottom,
    Color? tabletSceneHillBack,
    Color? tabletSceneHillFront,
    Color? tabletSceneCloud,
    Color? tabletSceneSparkle,
    Color? nightSkyTwinkle,
    Color? stepStripGoalFill,
    Color? stepStripGoalBorder,
    Color? tabletSceneGroundShadow,
    Color? loginLastUsedBg,
    Color? settingsDestructive,
    Color? settingsChevron,
    Color? settingsCardLabel,
    Color? settingsCardValue,
    Color? myInfoMetaText,
    Color? myInfoMutedIcon,
    Color? settingsToggleOn,
    Color? settingsToggleOff,
    Color? settingsGroupBg,
    Color? settingsGroupDivider,
    Color? settingsGroupLabel,
    Color? segmentedTabAccent,
    Color? segmentedTabUnselectedLabel,
    Color? peopleMeBadgeBg,
    Color? peopleMeBadgeText,
    Color? peopleGuardianChipBg,
    Color? peopleGuardianChipText,
    Color? peopleCaregiverChipBg,
    Color? peopleCaregiverChipText,
    Color? peopleRowBg,
    Color? peopleTextPrimary,
    Color? peopleTextSecondary,
    Color? peopleGuardianChipBorder,
    Color? peopleCaregiverChipBorder,
    Color? peopleChevron,
    Color? peopleEditPlaceholder,
    Color? peopleEditChipIdleText,
    Color? cardPhotoSlotDash,
    Color? creditCardBg,
    Color? creditBarTrack,
    Color? creditBarFill,
    Color? creditDivider,
    Color? creditAccentText,
    Color? creditNoticeBg,
    Color? creditNumberText,
    Color? creditMutedText,
    Color? creditHistoryMutedText,
    Color? notificationIconBackground,
    Color? notificationIconForeground,
    Color? notificationUnreadDot,
    Color? notificationRowText,
    Color? notificationMutedText,
    Color? notificationPermissionBannerBg,
    Color? notificationBellIcon,
    Color? notificationBellUnreadDot,
    Color? notificationBellUnreadDotBorder,
    Color? loginKakaoBg,
    Color? loginKakaoLabel,
    Color? loginNaverBg,
    Color? loginNaverLabel,
    Color? glassFill,
    Color? glassBorder,
    Color? rewardBannerBg,
    Color? linkTimer,
    Color? linkRetryChipBg,
    Color? linkLaterLabel,
    Color? loginButtonShadow,
    Color? loginAppleBg,
    Color? loginAppleLabel,
    Color? consentSelectedFill,
    Color? consentSelectedBorder,
    Color? dlpBadgeText,
    Color? homeHeroStart,
    Color? homeHeroEnd,
    Color? completionBgTop,
    Color? completionBgBottom,
    Color? completionInk,
    Color? completionSubtle,
    Color? stepBadge1,
    Color? stepBadge2,
    Color? stepBadge3,
    Color? stepBadge4,
    Color? noticeImagePlaceholder,
    Color? noticeHideLabel,
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
      buttonNeutral: buttonNeutral ?? this.buttonNeutral,
      buttonNeutralText: buttonNeutralText ?? this.buttonNeutralText,
      sheetHandle: sheetHandle ?? this.sheetHandle,
      sheetTitleText: sheetTitleText ?? this.sheetTitleText,
      dialogTitleText: dialogTitleText ?? this.dialogTitleText,
      dialogNeutral: dialogNeutral ?? this.dialogNeutral,
      dialogNeutralText: dialogNeutralText ?? this.dialogNeutralText,
      dialogDanger: dialogDanger ?? this.dialogDanger,
      danger: danger ?? this.danger,
      dangerText: dangerText ?? this.dangerText,
      highlightFill: highlightFill ?? this.highlightFill,
      highlightBorder: highlightBorder ?? this.highlightBorder,
      goalSelectedFill: goalSelectedFill ?? this.goalSelectedFill,
      goalSelectedBorder: goalSelectedBorder ?? this.goalSelectedBorder,
      libraryNewOutline: libraryNewOutline ?? this.libraryNewOutline,
      talkOriginBandFill: talkOriginBandFill ?? this.talkOriginBandFill,
      talkOriginBandAction: talkOriginBandAction ?? this.talkOriginBandAction,
      talkCardBorder: talkCardBorder ?? this.talkCardBorder,
      talkTitleText: talkTitleText ?? this.talkTitleText,
      talkMetaText: talkMetaText ?? this.talkMetaText,
      talkMetaIcon: talkMetaIcon ?? this.talkMetaIcon,
      talkPopularCardFill: talkPopularCardFill ?? this.talkPopularCardFill,
      metaDivider: metaDivider ?? this.metaDivider,
      talkSectionDivider: talkSectionDivider ?? this.talkSectionDivider,
      talkChoiceSelectedFill: talkChoiceSelectedFill ?? this.talkChoiceSelectedFill,
      talkChoiceSelectedBorder: talkChoiceSelectedBorder ?? this.talkChoiceSelectedBorder,
      talkChoiceRadioBorder: talkChoiceRadioBorder ?? this.talkChoiceRadioBorder,
      talkAccentText: talkAccentText ?? this.talkAccentText,
      talkPanelFill: talkPanelFill ?? this.talkPanelFill,
      talkCommentFill: talkCommentFill ?? this.talkCommentFill,
      talkCommentMineName: talkCommentMineName ?? this.talkCommentMineName,
      talkImportGroupSelectedFill: talkImportGroupSelectedFill ?? this.talkImportGroupSelectedFill,
      talkImportGroupSelectedStroke: talkImportGroupSelectedStroke ?? this.talkImportGroupSelectedStroke,
      talkCommentFieldFill: talkCommentFieldFill ?? this.talkCommentFieldFill,
      talkBlurChoicePanelFill: talkBlurChoicePanelFill ?? this.talkBlurChoicePanelFill,
      talkBlurChoiceSelectedFill: talkBlurChoiceSelectedFill ?? this.talkBlurChoiceSelectedFill,
      talkBlurChoiceFill: talkBlurChoiceFill ?? this.talkBlurChoiceFill,
      talkBlurChoiceLabel: talkBlurChoiceLabel ?? this.talkBlurChoiceLabel,
      talkNoteText: talkNoteText ?? this.talkNoteText,
      talkNoteHint: talkNoteHint ?? this.talkNoteHint,
      foxSelectedFill: foxSelectedFill ?? this.foxSelectedFill,
      foxSelectedBorder: foxSelectedBorder ?? this.foxSelectedBorder,
      catSelectedFill: catSelectedFill ?? this.catSelectedFill,
      catSelectedBorder: catSelectedBorder ?? this.catSelectedBorder,
      brandPeach: brandPeach ?? this.brandPeach,
      brandOrange: brandOrange ?? this.brandOrange,
      accentYellow: accentYellow ?? this.accentYellow,
      splashPlain: splashPlain ?? this.splashPlain,
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
      navBackground: navBackground ?? this.navBackground,
      navDivider: navDivider ?? this.navDivider,
      navIconSelected: navIconSelected ?? this.navIconSelected,
      navIconUnselected: navIconUnselected ?? this.navIconUnselected,
      navSelectedFill: navSelectedFill ?? this.navSelectedFill,
      navItemUnselected: navItemUnselected ?? this.navItemUnselected,
      folderFill: folderFill ?? this.folderFill,
      folderStroke: folderStroke ?? this.folderStroke,
      libraryTileLabel: libraryTileLabel ?? this.libraryTileLabel,
      homeCardShadow: homeCardShadow ?? this.homeCardShadow,
      homeCardIconBg: homeCardIconBg ?? this.homeCardIconBg,
      glassSurface: glassSurface ?? this.glassSurface,
      glassChip: glassChip ?? this.glassChip,
      promptMuted: promptMuted ?? this.promptMuted,
      glassShadow: glassShadow ?? this.glassShadow,
      auroraMint: auroraMint ?? this.auroraMint,
      auroraViolet: auroraViolet ?? this.auroraViolet,
      auroraYellow: auroraYellow ?? this.auroraYellow,
      auroraRewardViolet: auroraRewardViolet ?? this.auroraRewardViolet,
      auroraRewardPink: auroraRewardPink ?? this.auroraRewardPink,
      auroraRewardRose: auroraRewardRose ?? this.auroraRewardRose,
      auroraPreparingHaze: auroraPreparingHaze ?? this.auroraPreparingHaze,
      auroraPreparingOrchid: auroraPreparingOrchid ?? this.auroraPreparingOrchid,
      auroraQuestionPeri: auroraQuestionPeri ?? this.auroraQuestionPeri,
      auroraQuestionSky: auroraQuestionSky ?? this.auroraQuestionSky,
      auroraQuestionIndigo: auroraQuestionIndigo ?? this.auroraQuestionIndigo,
      auroraGeneratingMint: auroraGeneratingMint ?? this.auroraGeneratingMint,
      auroraGeneratingCoral: auroraGeneratingCoral ?? this.auroraGeneratingCoral,
      auroraGeneratingLemon: auroraGeneratingLemon ?? this.auroraGeneratingLemon,
      auroraPlanetFade: auroraPlanetFade ?? this.auroraPlanetFade,
      auroraRewardFade: auroraRewardFade ?? this.auroraRewardFade,
      stageDone: stageDone ?? this.stageDone,
      stagePending: stagePending ?? this.stagePending,
      stagePendingText: stagePendingText ?? this.stagePendingText,
      checkDone: checkDone ?? this.checkDone,
      checkIdleBorder: checkIdleBorder ?? this.checkIdleBorder,
      rewardBadgeTop: rewardBadgeTop ?? this.rewardBadgeTop,
      rewardBadgeBottom: rewardBadgeBottom ?? this.rewardBadgeBottom,
      rewardEmptyLabel: rewardEmptyLabel ?? this.rewardEmptyLabel,
      consentCheckIdle: consentCheckIdle ?? this.consentCheckIdle,
      roleElumi: roleElumi ?? this.roleElumi,
      checkPending: checkPending ?? this.checkPending,
      rewardBackdropTop: rewardBackdropTop ?? this.rewardBackdropTop,
      rewardBackdropBottom: rewardBackdropBottom ?? this.rewardBackdropBottom,
      routineDoneBackdropBottom:
          routineDoneBackdropBottom ?? this.routineDoneBackdropBottom,
      rewardStar: rewardStar ?? this.rewardStar,
      rewardStarGlow: rewardStarGlow ?? this.rewardStarGlow,
      rewardStarHalo: rewardStarHalo ?? this.rewardStarHalo,
      rewardStarGreen: rewardStarGreen ?? this.rewardStarGreen,
      rewardStarPurple: rewardStarPurple ?? this.rewardStarPurple,
      starDecoGlowGreen: starDecoGlowGreen ?? this.starDecoGlowGreen,
      starDecoGlowPurple: starDecoGlowPurple ?? this.starDecoGlowPurple,
      rewardButton: rewardButton ?? this.rewardButton,
      rewardGroundShadow: rewardGroundShadow ?? this.rewardGroundShadow,
      childEmptyShadow: childEmptyShadow ?? this.childEmptyShadow,
      characterCardShadow: characterCardShadow ?? this.characterCardShadow,
      routineTileBg: routineTileBg ?? this.routineTileBg,
      routineRingTrack: routineRingTrack ?? this.routineRingTrack,
      routineRingProgress: routineRingProgress ?? this.routineRingProgress,
      routineTileSwiped: routineTileSwiped ?? this.routineTileSwiped,
      routineSwipeDelete: routineSwipeDelete ?? this.routineSwipeDelete,
      routineSwipeEdit: routineSwipeEdit ?? this.routineSwipeEdit,
      routineTileLabel: routineTileLabel ?? this.routineTileLabel,
      routineTileReward: routineTileReward ?? this.routineTileReward,
      routineDragHandle: routineDragHandle ?? this.routineDragHandle,
      routineCreateStart: routineCreateStart ?? this.routineCreateStart,
      routineCreateEnd: routineCreateEnd ?? this.routineCreateEnd,
      routineCreateGlow: routineCreateGlow ?? this.routineCreateGlow,
      routineEmptyHint: routineEmptyHint ?? this.routineEmptyHint,
      childTileDone: childTileDone ?? this.childTileDone,
      starCount: starCount ?? this.starCount,
      rewardChipHighlight: rewardChipHighlight ?? this.rewardChipHighlight,
      coachScrim: coachScrim ?? this.coachScrim,
      coachAccent: coachAccent ?? this.coachAccent,
      coachText: coachText ?? this.coachText,
      starsNumberStart: starsNumberStart ?? this.starsNumberStart,
      editChipBg: editChipBg ?? this.editChipBg,
      editChipLabel: editChipLabel ?? this.editChipLabel,
      topBarActionText: topBarActionText ?? this.topBarActionText,
      sheetFieldLabelText: sheetFieldLabelText ?? this.sheetFieldLabelText,
      sheetScrim: sheetScrim ?? this.sheetScrim,
      dialogScrim: dialogScrim ?? this.dialogScrim,
      rewardLineLead: rewardLineLead ?? this.rewardLineLead,
      editChipPressedBg: editChipPressedBg ?? this.editChipPressedBg,
      tabletSceneSkyTop: tabletSceneSkyTop ?? this.tabletSceneSkyTop,
      tabletSceneSkyBottom: tabletSceneSkyBottom ?? this.tabletSceneSkyBottom,
      tabletSceneHillBack: tabletSceneHillBack ?? this.tabletSceneHillBack,
      tabletSceneHillFront: tabletSceneHillFront ?? this.tabletSceneHillFront,
      tabletSceneCloud: tabletSceneCloud ?? this.tabletSceneCloud,
      tabletSceneSparkle: tabletSceneSparkle ?? this.tabletSceneSparkle,
      nightSkyTwinkle: nightSkyTwinkle ?? this.nightSkyTwinkle,
      stepStripGoalFill: stepStripGoalFill ?? this.stepStripGoalFill,
      stepStripGoalBorder: stepStripGoalBorder ?? this.stepStripGoalBorder,
      tabletSceneGroundShadow: tabletSceneGroundShadow ?? this.tabletSceneGroundShadow,
      loginLastUsedBg: loginLastUsedBg ?? this.loginLastUsedBg,
      settingsDestructive: settingsDestructive ?? this.settingsDestructive,
      settingsChevron: settingsChevron ?? this.settingsChevron,
      settingsCardLabel: settingsCardLabel ?? this.settingsCardLabel,
      settingsCardValue: settingsCardValue ?? this.settingsCardValue,
      myInfoMetaText: myInfoMetaText ?? this.myInfoMetaText,
      myInfoMutedIcon: myInfoMutedIcon ?? this.myInfoMutedIcon,
      settingsToggleOn: settingsToggleOn ?? this.settingsToggleOn,
      settingsToggleOff: settingsToggleOff ?? this.settingsToggleOff,
      settingsGroupBg: settingsGroupBg ?? this.settingsGroupBg,
      settingsGroupDivider: settingsGroupDivider ?? this.settingsGroupDivider,
      settingsGroupLabel: settingsGroupLabel ?? this.settingsGroupLabel,
      segmentedTabAccent: segmentedTabAccent ?? this.segmentedTabAccent,
      segmentedTabUnselectedLabel: segmentedTabUnselectedLabel ?? this.segmentedTabUnselectedLabel,
      peopleMeBadgeBg: peopleMeBadgeBg ?? this.peopleMeBadgeBg,
      peopleMeBadgeText: peopleMeBadgeText ?? this.peopleMeBadgeText,
      peopleGuardianChipBg: peopleGuardianChipBg ?? this.peopleGuardianChipBg,
      peopleGuardianChipText: peopleGuardianChipText ?? this.peopleGuardianChipText,
      peopleCaregiverChipBg: peopleCaregiverChipBg ?? this.peopleCaregiverChipBg,
      peopleCaregiverChipText: peopleCaregiverChipText ?? this.peopleCaregiverChipText,
      peopleRowBg: peopleRowBg ?? this.peopleRowBg,
      peopleTextPrimary: peopleTextPrimary ?? this.peopleTextPrimary,
      peopleTextSecondary: peopleTextSecondary ?? this.peopleTextSecondary,
      peopleGuardianChipBorder: peopleGuardianChipBorder ?? this.peopleGuardianChipBorder,
      peopleCaregiverChipBorder: peopleCaregiverChipBorder ?? this.peopleCaregiverChipBorder,
      peopleChevron: peopleChevron ?? this.peopleChevron,
      peopleEditPlaceholder: peopleEditPlaceholder ?? this.peopleEditPlaceholder,
      peopleEditChipIdleText: peopleEditChipIdleText ?? this.peopleEditChipIdleText,
      cardPhotoSlotDash: cardPhotoSlotDash ?? this.cardPhotoSlotDash,
      creditCardBg: creditCardBg ?? this.creditCardBg,
      creditBarTrack: creditBarTrack ?? this.creditBarTrack,
      creditBarFill: creditBarFill ?? this.creditBarFill,
      creditDivider: creditDivider ?? this.creditDivider,
      creditAccentText: creditAccentText ?? this.creditAccentText,
      creditNoticeBg: creditNoticeBg ?? this.creditNoticeBg,
      creditNumberText: creditNumberText ?? this.creditNumberText,
      creditMutedText: creditMutedText ?? this.creditMutedText,
      creditHistoryMutedText: creditHistoryMutedText ?? this.creditHistoryMutedText,
      notificationIconBackground: notificationIconBackground ?? this.notificationIconBackground,
      notificationIconForeground: notificationIconForeground ?? this.notificationIconForeground,
      notificationUnreadDot: notificationUnreadDot ?? this.notificationUnreadDot,
      notificationRowText: notificationRowText ?? this.notificationRowText,
      notificationMutedText: notificationMutedText ?? this.notificationMutedText,
      notificationPermissionBannerBg: notificationPermissionBannerBg ?? this.notificationPermissionBannerBg,
      notificationBellIcon: notificationBellIcon ?? this.notificationBellIcon,
      notificationBellUnreadDot: notificationBellUnreadDot ?? this.notificationBellUnreadDot,
      notificationBellUnreadDotBorder: notificationBellUnreadDotBorder ?? this.notificationBellUnreadDotBorder,
      loginKakaoBg: loginKakaoBg ?? this.loginKakaoBg,
      loginKakaoLabel: loginKakaoLabel ?? this.loginKakaoLabel,
      loginNaverBg: loginNaverBg ?? this.loginNaverBg,
      loginNaverLabel: loginNaverLabel ?? this.loginNaverLabel,
      glassFill: glassFill ?? this.glassFill,
      glassBorder: glassBorder ?? this.glassBorder,
      rewardBannerBg: rewardBannerBg ?? this.rewardBannerBg,
      linkTimer: linkTimer ?? this.linkTimer,
      linkRetryChipBg: linkRetryChipBg ?? this.linkRetryChipBg,
      linkLaterLabel: linkLaterLabel ?? this.linkLaterLabel,
      loginButtonShadow: loginButtonShadow ?? this.loginButtonShadow,
      loginAppleBg: loginAppleBg ?? this.loginAppleBg,
      loginAppleLabel: loginAppleLabel ?? this.loginAppleLabel,
      consentSelectedFill: consentSelectedFill ?? this.consentSelectedFill,
      consentSelectedBorder:
          consentSelectedBorder ?? this.consentSelectedBorder,
      dlpBadgeText: dlpBadgeText ?? this.dlpBadgeText,
      homeHeroStart: homeHeroStart ?? this.homeHeroStart,
      homeHeroEnd: homeHeroEnd ?? this.homeHeroEnd,
      completionBgTop: completionBgTop ?? this.completionBgTop,
      completionBgBottom: completionBgBottom ?? this.completionBgBottom,
      completionInk: completionInk ?? this.completionInk,
      completionSubtle: completionSubtle ?? this.completionSubtle,
      stepBadge1: stepBadge1 ?? this.stepBadge1,
      stepBadge2: stepBadge2 ?? this.stepBadge2,
      stepBadge3: stepBadge3 ?? this.stepBadge3,
      stepBadge4: stepBadge4 ?? this.stepBadge4,
      noticeImagePlaceholder: noticeImagePlaceholder ?? this.noticeImagePlaceholder,
      noticeHideLabel: noticeHideLabel ?? this.noticeHideLabel,
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
      buttonEnabledText: Color.lerp(
        buttonEnabledText,
        other.buttonEnabledText,
        t,
      )!,
      buttonDisabled: Color.lerp(buttonDisabled, other.buttonDisabled, t)!,
      buttonDisabledText: Color.lerp(
        buttonDisabledText,
        other.buttonDisabledText,
        t,
      )!,
      buttonNeutral: Color.lerp(buttonNeutral, other.buttonNeutral, t)!,
      buttonNeutralText: Color.lerp(
        buttonNeutralText,
        other.buttonNeutralText,
        t,
      )!,
      sheetHandle: Color.lerp(sheetHandle, other.sheetHandle, t)!,
      sheetTitleText: Color.lerp(sheetTitleText, other.sheetTitleText, t)!,
      dialogTitleText: Color.lerp(dialogTitleText, other.dialogTitleText, t)!,
      dialogNeutral: Color.lerp(dialogNeutral, other.dialogNeutral, t)!,
      dialogNeutralText: Color.lerp(
        dialogNeutralText,
        other.dialogNeutralText,
        t,
      )!,
      dialogDanger: Color.lerp(dialogDanger, other.dialogDanger, t)!,
      danger: Color.lerp(danger, other.danger, t)!,
      dangerText: Color.lerp(dangerText, other.dangerText, t)!,
      highlightFill: Color.lerp(highlightFill, other.highlightFill, t)!,
      highlightBorder: Color.lerp(highlightBorder, other.highlightBorder, t)!,
      goalSelectedFill: Color.lerp(
        goalSelectedFill,
        other.goalSelectedFill,
        t,
      )!,
      goalSelectedBorder: Color.lerp(
        goalSelectedBorder,
        other.goalSelectedBorder,
        t,
      )!,
      libraryNewOutline: Color.lerp(
        libraryNewOutline,
        other.libraryNewOutline,
        t,
      )!,
      talkOriginBandFill: Color.lerp(
        talkOriginBandFill,
        other.talkOriginBandFill,
        t,
      )!,
      talkOriginBandAction: Color.lerp(
        talkOriginBandAction,
        other.talkOriginBandAction,
        t,
      )!,
      talkCardBorder: Color.lerp(talkCardBorder, other.talkCardBorder, t)!,
      talkTitleText: Color.lerp(talkTitleText, other.talkTitleText, t)!,
      talkMetaText: Color.lerp(talkMetaText, other.talkMetaText, t)!,
      talkMetaIcon: Color.lerp(talkMetaIcon, other.talkMetaIcon, t)!,
      talkPopularCardFill: Color.lerp(talkPopularCardFill, other.talkPopularCardFill, t)!,
      metaDivider: Color.lerp(metaDivider, other.metaDivider, t)!,
      talkSectionDivider: Color.lerp(talkSectionDivider, other.talkSectionDivider, t)!,
      talkChoiceSelectedFill: Color.lerp(talkChoiceSelectedFill, other.talkChoiceSelectedFill, t)!,
      talkChoiceSelectedBorder: Color.lerp(talkChoiceSelectedBorder, other.talkChoiceSelectedBorder, t)!,
      talkChoiceRadioBorder: Color.lerp(talkChoiceRadioBorder, other.talkChoiceRadioBorder, t)!,
      talkAccentText: Color.lerp(talkAccentText, other.talkAccentText, t)!,
      talkPanelFill: Color.lerp(talkPanelFill, other.talkPanelFill, t)!,
      talkCommentFill: Color.lerp(talkCommentFill, other.talkCommentFill, t)!,
      talkCommentMineName: Color.lerp(talkCommentMineName, other.talkCommentMineName, t)!,
      talkImportGroupSelectedFill: Color.lerp(talkImportGroupSelectedFill, other.talkImportGroupSelectedFill, t)!,
      talkImportGroupSelectedStroke: Color.lerp(talkImportGroupSelectedStroke, other.talkImportGroupSelectedStroke, t)!,
      talkCommentFieldFill: Color.lerp(talkCommentFieldFill, other.talkCommentFieldFill, t)!,
      talkBlurChoicePanelFill: Color.lerp(talkBlurChoicePanelFill, other.talkBlurChoicePanelFill, t)!,
      talkBlurChoiceSelectedFill: Color.lerp(talkBlurChoiceSelectedFill, other.talkBlurChoiceSelectedFill, t)!,
      talkBlurChoiceFill: Color.lerp(talkBlurChoiceFill, other.talkBlurChoiceFill, t)!,
      talkBlurChoiceLabel: Color.lerp(talkBlurChoiceLabel, other.talkBlurChoiceLabel, t)!,
      talkNoteText: Color.lerp(talkNoteText, other.talkNoteText, t)!,
      talkNoteHint: Color.lerp(talkNoteHint, other.talkNoteHint, t)!,
      foxSelectedFill: Color.lerp(foxSelectedFill, other.foxSelectedFill, t)!,
      foxSelectedBorder: Color.lerp(
        foxSelectedBorder,
        other.foxSelectedBorder,
        t,
      )!,
      catSelectedFill: Color.lerp(catSelectedFill, other.catSelectedFill, t)!,
      catSelectedBorder: Color.lerp(
        catSelectedBorder,
        other.catSelectedBorder,
        t,
      )!,
      brandPeach: Color.lerp(brandPeach, other.brandPeach, t)!,
      brandOrange: Color.lerp(brandOrange, other.brandOrange, t)!,
      accentYellow: Color.lerp(accentYellow, other.accentYellow, t)!,
      splashPlain: Color.lerp(splashPlain, other.splashPlain, t)!,
      splashTop: Color.lerp(splashTop, other.splashTop, t)!,
      splashBottom: Color.lerp(splashBottom, other.splashBottom, t)!,
      splashHill: Color.lerp(splashHill, other.splashHill, t)!,
      splashHillGlow: Color.lerp(splashHillGlow, other.splashHillGlow, t)!,
      splashOrbGlowCore: Color.lerp(
        splashOrbGlowCore,
        other.splashOrbGlowCore,
        t,
      )!,
      splashOrbGlowHalo: Color.lerp(
        splashOrbGlowHalo,
        other.splashOrbGlowHalo,
        t,
      )!,
      splashTitle: Color.lerp(splashTitle, other.splashTitle, t)!,
      homeCardGradientStart: Color.lerp(
        homeCardGradientStart,
        other.homeCardGradientStart,
        t,
      )!,
      homeCardGradientEnd: Color.lerp(
        homeCardGradientEnd,
        other.homeCardGradientEnd,
        t,
      )!,
      homeCardTitle: Color.lerp(homeCardTitle, other.homeCardTitle, t)!,
      navBackground: Color.lerp(navBackground, other.navBackground, t)!,
      navDivider: Color.lerp(navDivider, other.navDivider, t)!,
      navIconSelected: Color.lerp(navIconSelected, other.navIconSelected, t)!,
      navIconUnselected: Color.lerp(navIconUnselected, other.navIconUnselected, t)!,
      navSelectedFill: Color.lerp(navSelectedFill, other.navSelectedFill, t)!,
      navItemUnselected: Color.lerp(navItemUnselected, other.navItemUnselected, t)!,
      folderFill: Color.lerp(folderFill, other.folderFill, t)!,
      folderStroke: Color.lerp(folderStroke, other.folderStroke, t)!,
      libraryTileLabel: Color.lerp(libraryTileLabel, other.libraryTileLabel, t)!,
      homeCardShadow: Color.lerp(homeCardShadow, other.homeCardShadow, t)!,
      homeCardIconBg: Color.lerp(homeCardIconBg, other.homeCardIconBg, t)!,
      glassSurface: Color.lerp(glassSurface, other.glassSurface, t)!,
      glassChip: Color.lerp(glassChip, other.glassChip, t)!,
      promptMuted: Color.lerp(promptMuted, other.promptMuted, t)!,
      glassShadow: Color.lerp(glassShadow, other.glassShadow, t)!,
      auroraMint: Color.lerp(auroraMint, other.auroraMint, t)!,
      auroraViolet: Color.lerp(auroraViolet, other.auroraViolet, t)!,
      auroraYellow: Color.lerp(auroraYellow, other.auroraYellow, t)!,
      auroraRewardViolet: Color.lerp(
        auroraRewardViolet,
        other.auroraRewardViolet,
        t,
      )!,
      auroraRewardPink: Color.lerp(auroraRewardPink, other.auroraRewardPink, t)!,
      auroraRewardRose: Color.lerp(auroraRewardRose, other.auroraRewardRose, t)!,
      auroraPreparingHaze: Color.lerp(auroraPreparingHaze, other.auroraPreparingHaze, t)!,
      auroraPreparingOrchid: Color.lerp(auroraPreparingOrchid, other.auroraPreparingOrchid, t)!,
      auroraQuestionPeri: Color.lerp(auroraQuestionPeri, other.auroraQuestionPeri, t)!,
      auroraQuestionSky: Color.lerp(auroraQuestionSky, other.auroraQuestionSky, t)!,
      auroraQuestionIndigo: Color.lerp(auroraQuestionIndigo, other.auroraQuestionIndigo, t)!,
      auroraGeneratingMint: Color.lerp(auroraGeneratingMint, other.auroraGeneratingMint, t)!,
      auroraGeneratingCoral: Color.lerp(auroraGeneratingCoral, other.auroraGeneratingCoral, t)!,
      auroraGeneratingLemon: Color.lerp(auroraGeneratingLemon, other.auroraGeneratingLemon, t)!,
      auroraPlanetFade: Color.lerp(auroraPlanetFade, other.auroraPlanetFade, t)!,
      auroraRewardFade: Color.lerp(auroraRewardFade, other.auroraRewardFade, t)!,
      stageDone: Color.lerp(stageDone, other.stageDone, t)!,
      stagePending: Color.lerp(stagePending, other.stagePending, t)!,
      stagePendingText: Color.lerp(
        stagePendingText,
        other.stagePendingText,
        t,
      )!,
      checkDone: Color.lerp(checkDone, other.checkDone, t)!,
      checkIdleBorder: Color.lerp(checkIdleBorder, other.checkIdleBorder, t)!,
      rewardBadgeTop: Color.lerp(rewardBadgeTop, other.rewardBadgeTop, t)!,
      rewardBadgeBottom: Color.lerp(
        rewardBadgeBottom,
        other.rewardBadgeBottom,
        t,
      )!,
      rewardEmptyLabel: Color.lerp(
        rewardEmptyLabel,
        other.rewardEmptyLabel,
        t,
      )!,
      consentCheckIdle: Color.lerp(
        consentCheckIdle,
        other.consentCheckIdle,
        t,
      )!,
      roleElumi: Color.lerp(roleElumi, other.roleElumi, t)!,
      checkPending: Color.lerp(checkPending, other.checkPending, t)!,
      rewardBackdropTop: Color.lerp(
        rewardBackdropTop,
        other.rewardBackdropTop,
        t,
      )!,
      rewardBackdropBottom: Color.lerp(
        rewardBackdropBottom,
        other.rewardBackdropBottom,
        t,
      )!,
      routineDoneBackdropBottom: Color.lerp(
        routineDoneBackdropBottom,
        other.routineDoneBackdropBottom,
        t,
      )!,
      rewardStar: Color.lerp(rewardStar, other.rewardStar, t)!,
      rewardStarGlow: Color.lerp(rewardStarGlow, other.rewardStarGlow, t)!,
      rewardStarHalo: Color.lerp(rewardStarHalo, other.rewardStarHalo, t)!,
      rewardStarGreen: Color.lerp(rewardStarGreen, other.rewardStarGreen, t)!,
      rewardStarPurple: Color.lerp(
        rewardStarPurple,
        other.rewardStarPurple,
        t,
      )!,
      starDecoGlowGreen: Color.lerp(
        starDecoGlowGreen,
        other.starDecoGlowGreen,
        t,
      )!,
      starDecoGlowPurple: Color.lerp(
        starDecoGlowPurple,
        other.starDecoGlowPurple,
        t,
      )!,
      rewardButton: Color.lerp(rewardButton, other.rewardButton, t)!,
      rewardGroundShadow: Color.lerp(
        rewardGroundShadow,
        other.rewardGroundShadow,
        t,
      )!,
      childEmptyShadow: Color.lerp(
        childEmptyShadow,
        other.childEmptyShadow,
        t,
      )!,
      characterCardShadow: Color.lerp(
        characterCardShadow,
        other.characterCardShadow,
        t,
      )!,
      routineTileBg: Color.lerp(routineTileBg, other.routineTileBg, t)!,
      routineRingTrack: Color.lerp(
        routineRingTrack,
        other.routineRingTrack,
        t,
      )!,
      routineRingProgress: Color.lerp(
        routineRingProgress,
        other.routineRingProgress,
        t,
      )!,
      routineTileSwiped: Color.lerp(
        routineTileSwiped,
        other.routineTileSwiped,
        t,
      )!,
      routineSwipeDelete: Color.lerp(
        routineSwipeDelete,
        other.routineSwipeDelete,
        t,
      )!,
      routineSwipeEdit: Color.lerp(
        routineSwipeEdit,
        other.routineSwipeEdit,
        t,
      )!,
      routineTileLabel: Color.lerp(
        routineTileLabel,
        other.routineTileLabel,
        t,
      )!,
      routineTileReward: Color.lerp(
        routineTileReward,
        other.routineTileReward,
        t,
      )!,
      routineDragHandle: Color.lerp(
        routineDragHandle,
        other.routineDragHandle,
        t,
      )!,
      routineCreateStart: Color.lerp(
        routineCreateStart,
        other.routineCreateStart,
        t,
      )!,
      routineCreateEnd: Color.lerp(
        routineCreateEnd,
        other.routineCreateEnd,
        t,
      )!,
      routineCreateGlow: Color.lerp(
        routineCreateGlow,
        other.routineCreateGlow,
        t,
      )!,
      routineEmptyHint: Color.lerp(
        routineEmptyHint,
        other.routineEmptyHint,
        t,
      )!,
      childTileDone: Color.lerp(childTileDone, other.childTileDone, t)!,
      starCount: Color.lerp(starCount, other.starCount, t)!,
      rewardChipHighlight:
          Color.lerp(rewardChipHighlight, other.rewardChipHighlight, t)!,
      coachScrim: Color.lerp(coachScrim, other.coachScrim, t)!,
      coachAccent: Color.lerp(coachAccent, other.coachAccent, t)!,
      coachText: Color.lerp(coachText, other.coachText, t)!,
      starsNumberStart: Color.lerp(
        starsNumberStart,
        other.starsNumberStart,
        t,
      )!,
      editChipBg: Color.lerp(editChipBg, other.editChipBg, t)!,
      editChipLabel: Color.lerp(editChipLabel, other.editChipLabel, t)!,
      topBarActionText: Color.lerp(topBarActionText, other.topBarActionText, t)!,
      sheetFieldLabelText: Color.lerp(sheetFieldLabelText, other.sheetFieldLabelText, t)!,
      sheetScrim: Color.lerp(sheetScrim, other.sheetScrim, t)!,
      dialogScrim: Color.lerp(dialogScrim, other.dialogScrim, t)!,
      rewardLineLead: Color.lerp(rewardLineLead, other.rewardLineLead, t)!,
      editChipPressedBg: Color.lerp(editChipPressedBg, other.editChipPressedBg, t)!,
      tabletSceneSkyTop: Color.lerp(tabletSceneSkyTop, other.tabletSceneSkyTop, t)!,
      tabletSceneSkyBottom: Color.lerp(tabletSceneSkyBottom, other.tabletSceneSkyBottom, t)!,
      tabletSceneHillBack: Color.lerp(tabletSceneHillBack, other.tabletSceneHillBack, t)!,
      tabletSceneHillFront: Color.lerp(tabletSceneHillFront, other.tabletSceneHillFront, t)!,
      tabletSceneCloud: Color.lerp(tabletSceneCloud, other.tabletSceneCloud, t)!,
      tabletSceneSparkle: Color.lerp(tabletSceneSparkle, other.tabletSceneSparkle, t)!,
      nightSkyTwinkle: Color.lerp(nightSkyTwinkle, other.nightSkyTwinkle, t)!,
      stepStripGoalFill: Color.lerp(stepStripGoalFill, other.stepStripGoalFill, t)!,
      stepStripGoalBorder: Color.lerp(stepStripGoalBorder, other.stepStripGoalBorder, t)!,
      tabletSceneGroundShadow: Color.lerp(tabletSceneGroundShadow, other.tabletSceneGroundShadow, t)!,
      loginLastUsedBg: Color.lerp(loginLastUsedBg, other.loginLastUsedBg, t)!,
      settingsDestructive:
          Color.lerp(settingsDestructive, other.settingsDestructive, t)!,
      settingsChevron: Color.lerp(settingsChevron, other.settingsChevron, t)!,
      settingsCardLabel: Color.lerp(settingsCardLabel, other.settingsCardLabel, t)!,
      settingsCardValue: Color.lerp(settingsCardValue, other.settingsCardValue, t)!,
      myInfoMetaText: Color.lerp(myInfoMetaText, other.myInfoMetaText, t)!,
      myInfoMutedIcon: Color.lerp(myInfoMutedIcon, other.myInfoMutedIcon, t)!,
      settingsToggleOn: Color.lerp(settingsToggleOn, other.settingsToggleOn, t)!,
      settingsToggleOff: Color.lerp(settingsToggleOff, other.settingsToggleOff, t)!,
      settingsGroupBg: Color.lerp(settingsGroupBg, other.settingsGroupBg, t)!,
      settingsGroupDivider: Color.lerp(settingsGroupDivider, other.settingsGroupDivider, t)!,
      settingsGroupLabel: Color.lerp(settingsGroupLabel, other.settingsGroupLabel, t)!,
      segmentedTabAccent: Color.lerp(segmentedTabAccent, other.segmentedTabAccent, t)!,
      segmentedTabUnselectedLabel: Color.lerp(segmentedTabUnselectedLabel, other.segmentedTabUnselectedLabel, t)!,
      peopleMeBadgeBg: Color.lerp(peopleMeBadgeBg, other.peopleMeBadgeBg, t)!,
      peopleMeBadgeText: Color.lerp(peopleMeBadgeText, other.peopleMeBadgeText, t)!,
      peopleGuardianChipBg: Color.lerp(peopleGuardianChipBg, other.peopleGuardianChipBg, t)!,
      peopleGuardianChipText: Color.lerp(peopleGuardianChipText, other.peopleGuardianChipText, t)!,
      peopleCaregiverChipBg: Color.lerp(peopleCaregiverChipBg, other.peopleCaregiverChipBg, t)!,
      peopleCaregiverChipText: Color.lerp(peopleCaregiverChipText, other.peopleCaregiverChipText, t)!,
      peopleRowBg: Color.lerp(peopleRowBg, other.peopleRowBg, t)!,
      peopleTextPrimary: Color.lerp(peopleTextPrimary, other.peopleTextPrimary, t)!,
      peopleTextSecondary: Color.lerp(peopleTextSecondary, other.peopleTextSecondary, t)!,
      peopleGuardianChipBorder: Color.lerp(peopleGuardianChipBorder, other.peopleGuardianChipBorder, t)!,
      peopleCaregiverChipBorder: Color.lerp(peopleCaregiverChipBorder, other.peopleCaregiverChipBorder, t)!,
      peopleChevron: Color.lerp(peopleChevron, other.peopleChevron, t)!,
      peopleEditPlaceholder: Color.lerp(peopleEditPlaceholder, other.peopleEditPlaceholder, t)!,
      peopleEditChipIdleText: Color.lerp(peopleEditChipIdleText, other.peopleEditChipIdleText, t)!,
      cardPhotoSlotDash:
          Color.lerp(cardPhotoSlotDash, other.cardPhotoSlotDash, t)!,
      creditCardBg: Color.lerp(creditCardBg, other.creditCardBg, t)!,
      creditBarTrack: Color.lerp(creditBarTrack, other.creditBarTrack, t)!,
      creditBarFill: Color.lerp(creditBarFill, other.creditBarFill, t)!,
      creditDivider: Color.lerp(creditDivider, other.creditDivider, t)!,
      creditAccentText: Color.lerp(creditAccentText, other.creditAccentText, t)!,
      creditNoticeBg: Color.lerp(creditNoticeBg, other.creditNoticeBg, t)!,
      creditNumberText: Color.lerp(creditNumberText, other.creditNumberText, t)!,
      creditMutedText: Color.lerp(creditMutedText, other.creditMutedText, t)!,
      creditHistoryMutedText: Color.lerp(creditHistoryMutedText, other.creditHistoryMutedText, t)!,
      notificationIconBackground: Color.lerp(notificationIconBackground, other.notificationIconBackground, t)!,
      notificationIconForeground: Color.lerp(notificationIconForeground, other.notificationIconForeground, t)!,
      notificationUnreadDot: Color.lerp(notificationUnreadDot, other.notificationUnreadDot, t)!,
      notificationRowText: Color.lerp(notificationRowText, other.notificationRowText, t)!,
      notificationMutedText: Color.lerp(notificationMutedText, other.notificationMutedText, t)!,
      notificationPermissionBannerBg: Color.lerp(notificationPermissionBannerBg, other.notificationPermissionBannerBg, t)!,
      notificationBellIcon: Color.lerp(notificationBellIcon, other.notificationBellIcon, t)!,
      notificationBellUnreadDot: Color.lerp(notificationBellUnreadDot, other.notificationBellUnreadDot, t)!,
      notificationBellUnreadDotBorder: Color.lerp(notificationBellUnreadDotBorder, other.notificationBellUnreadDotBorder, t)!,
      loginKakaoBg: Color.lerp(loginKakaoBg, other.loginKakaoBg, t)!,
      loginKakaoLabel: Color.lerp(loginKakaoLabel, other.loginKakaoLabel, t)!,
      loginNaverBg: Color.lerp(loginNaverBg, other.loginNaverBg, t)!,
      loginNaverLabel: Color.lerp(loginNaverLabel, other.loginNaverLabel, t)!,
      glassFill: Color.lerp(glassFill, other.glassFill, t)!,
      glassBorder: Color.lerp(glassBorder, other.glassBorder, t)!,
      rewardBannerBg: Color.lerp(rewardBannerBg, other.rewardBannerBg, t)!,
      linkTimer: Color.lerp(linkTimer, other.linkTimer, t)!,
      linkRetryChipBg: Color.lerp(linkRetryChipBg, other.linkRetryChipBg, t)!,
      linkLaterLabel: Color.lerp(linkLaterLabel, other.linkLaterLabel, t)!,
      loginButtonShadow: Color.lerp(
        loginButtonShadow,
        other.loginButtonShadow,
        t,
      )!,
      loginAppleBg: Color.lerp(loginAppleBg, other.loginAppleBg, t)!,
      loginAppleLabel: Color.lerp(loginAppleLabel, other.loginAppleLabel, t)!,
      consentSelectedFill: Color.lerp(
        consentSelectedFill,
        other.consentSelectedFill,
        t,
      )!,
      consentSelectedBorder: Color.lerp(
        consentSelectedBorder,
        other.consentSelectedBorder,
        t,
      )!,
      dlpBadgeText: Color.lerp(dlpBadgeText, other.dlpBadgeText, t)!,
      homeHeroStart: Color.lerp(homeHeroStart, other.homeHeroStart, t)!,
      homeHeroEnd: Color.lerp(homeHeroEnd, other.homeHeroEnd, t)!,
      completionBgTop: Color.lerp(completionBgTop, other.completionBgTop, t)!,
      completionBgBottom: Color.lerp(
        completionBgBottom,
        other.completionBgBottom,
        t,
      )!,
      completionInk: Color.lerp(completionInk, other.completionInk, t)!,
      completionSubtle: Color.lerp(
        completionSubtle,
        other.completionSubtle,
        t,
      )!,
      stepBadge1: Color.lerp(stepBadge1, other.stepBadge1, t)!,
      stepBadge2: Color.lerp(stepBadge2, other.stepBadge2, t)!,
      stepBadge3: Color.lerp(stepBadge3, other.stepBadge3, t)!,
      stepBadge4: Color.lerp(stepBadge4, other.stepBadge4, t)!,
      noticeImagePlaceholder: Color.lerp(noticeImagePlaceholder, other.noticeImagePlaceholder, t)!,
      noticeHideLabel: Color.lerp(noticeHideLabel, other.noticeHideLabel, t)!,
    );
  }

  /// 체크 순간 터지는 컨페티(색종이) 팔레트.
  ///
  /// Figma 시안(309:3648)에는 컨페티가 그려져 있지 않아 색 원본이 없다.
  /// 그래서 개별 토큰을 새로 만들지 않고 이미 있는 밝은 브랜드·보상 색을
  /// 모아 쓴다 — 이 색들이 바뀌면 컨페티도 같이 바뀌는 게 자연스럽다.
  /// (토큰 분리 기준: "항상 같이 바뀌어야 하는가" → 예)
  List<Color> get confetti => [
    checkDone, // 청록 — 체크 원과 같은 색이라 연출이 이어진다
    accentYellow, // 노랑
    brandOrange, // 주황
    brandPeach, // 살구
    catSelectedBorder, // 파랑
    rewardStarGreen, // 연두
    rewardStarPurple, // 보라
  ];
}
