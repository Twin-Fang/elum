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
    required this.docSection,
    required this.docBody,
    required this.linkCode,
    required this.linkTimer,
    required this.linkRetryChip,
    required this.dialogTitle,
    required this.dialogAction,
    required this.linkLater,
    required this.helpLink,
    required this.loginProvider,
    required this.consentAllAgree,
    required this.consentBadge,
    required this.consentLabel,
    required this.bodySmall,
    required this.childTileTitle,
    required this.ringPercent,
    required this.routineTileTitle,
    required this.routineTileMeta,
    required this.routineTileReward,
    required this.routineSectionLabel,
    required this.routineCreateLabel,
    required this.routineEmptyTitle,
    required this.routineEmptyPast,
    required this.starsCount,
    required this.stepBadgeNumber,
    required this.sheetTitle,
    required this.sheetStepTitle,
    required this.sheetStepBody,
    required this.sheetActionLabel,
    required this.editChipLabel,
    required this.childDetailTitle,
    required this.promptPlaceholder,
    required this.promptCaption,
    required this.lastLoginBadge,
    required this.appVersionTag,
    required this.settingsTileLabel,
    required this.creditTitle,
    required this.creditNumber,
    required this.creditBody,
    required this.creditCaption,
    required this.navTitle,
    required this.contactSheetTitle,
    required this.contactSheetEmail,
    required this.actionCardTitle,
    required this.noticeTitle,
    required this.noticeBody,
    required this.noticeHideLabel,
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

  /// 약관 전문의 섹션 제목 `0. 누가 입력하고…` (16/w700 Pretendard).
  ///
  /// 긴 글이라 제목용 둥근 폰트(Tmoney)를 쓰지 않는다 — 글자가 뭉쳐 읽기 어렵다.
  final TextStyle docSection;

  /// 약관 전문 본문 (14/w400 Pretendard). 화면 본문(`body`, 16 Tmoney)보다 작다.
  final TextStyle docBody;

  /// 연결 암호 여섯 글자 (40/w800). 이 화면에서 가장 큰 글자다.
  final TextStyle linkCode;

  /// 연결 암호 남은 시간 `09:59` (16/w500 Pretendard).
  final TextStyle linkTimer;

  /// `코드 다시 만들기` 칩 (14/w600 Pretendard).
  ///
  /// 추천 문구 칩(`chipLabel`, 14/w500)과 **굵기가 다르다.** 합치면 한쪽만
  /// 못 바꾼다.
  final TextStyle linkRetryChip;

  /// 팝업 제목 (18/w500 Pretendard).
  final TextStyle dialogTitle;

  /// 팝업 버튼 문구 (18/w600 Pretendard).
  final TextStyle dialogAction;

  /// `나중에 할게요` (16/w600 Pretendard).
  final TextStyle linkLater;

  /// 도움말 줄 — `보상이 왜 필요한가요?` (14/w400 Pretendard · 시안 `1082:4768`).
  final TextStyle helpLink;

  /// 소셜 로그인 버튼 문구 (18/w700 Pretendard).
  ///
  /// 앱 CTA(`button`, 22/w800 Tmoney)와 다르다 — 제공자 버튼은 카카오·네이버·Apple
  /// 브랜드 가이드의 리듬을 따르므로 시안 그대로 둔다 (이슈 #230).
  final TextStyle loginProvider;

  /// 약관 화면 전체 동의 버튼 문구 "서비스 이용약관 전체 동의" (20/w600 Pretendard).
  ///
  /// 이 화면군만 Pretendard다 — 제목·CTA는 Tmoney RoundWind 그대로다 (이슈 #226).
  final TextStyle consentAllAgree;

  /// 약관 항목 앞 `필수`/`선택` 배지 (16/w600 Pretendard).
  final TextStyle consentBadge;

  /// 약관 항목 제목 (16/w400 Pretendard).
  final TextStyle consentLabel;

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

  /// 일과 카드 제목 (Pretendard 600/16).
  /// cardTitle(Tmoney 800/17)과 다르다 — 목록에서 여러 줄이 겹치므로
  /// 둥근 폰트보다 좁고 또렷한 쪽이 읽힌다.
  final TextStyle routineTileTitle;

  /// 일과 카드의 `완료 시` 라벨과 날짜 (Pretendard 400/13).
  final TextStyle routineTileMeta;

  /// 일과 카드의 보상 문구 (Pretendard 500/13). 라벨과 같은 줄에 서므로
  /// 크기는 같고 굵기로만 값임을 드러낸다.
  final TextStyle routineTileReward;

  /// `오늘 일과` · `지난 일과` 섹션 제목 (Pretendard 600/14).
  /// sectionTitle(Tmoney 800/14)을 쓰지 않는다 — 개편 시안에서 섹션 제목이
  /// 본문 폰트로 바뀌고 색도 옅어졌다.
  final TextStyle routineSectionLabel;

  /// `새로운 일과 만들기` 버튼 문구 (Pretendard 500/17).
  final TextStyle routineCreateLabel;

  /// 빈 상태 첫 줄 (Pretendard 500/16). 일과 카드 제목(600)보다 얇다 —
  /// 진짜 일과가 아니라 자리를 지키는 문구다.
  final TextStyle routineEmptyTitle;

  /// `지난 일과가 없어요` (Pretendard 500/15). 오늘 쪽(16)보다 1 작다 — 시안 그대로다.
  final TextStyle routineEmptyPast;

  /// 아이_별 화면 누적 별 숫자 (80/w800).
  final TextStyle starsCount;

  /// 일과 시트의 단계 번호 뱃지 (30/w800, Figma 956:4084 `style_H23PME`).
  ///
  /// **[starsCount](80)를 빌려 쓰지 않는다.** 이름이 비슷해 한 번 그렇게 썼다가
  /// 40×68 뱃지 안에서 숫자가 잘렸다. 쓰임이 다르면 크기도 다르다.
  final TextStyle stepBadgeNumber;

  /// 일과 시트 제목 (Figma 956:4084 `타이틀` — Pretendard 20).
  ///
  /// `reviewTitle`(24)을 쓰지 않는다 — 그건 다른 화면도 함께 쓰므로 여기서 크기를
  /// 바꾸면 손대지 않은 화면까지 딸려 바뀐다. 시안이 이 화면군만 Pretendard로
  /// 그렸기에 글꼴도 다르다.
  final TextStyle sheetTitle;

  /// 일과 시트의 단계 제목 (Figma `963:4236` — Pretendard 16/600).
  /// `cardTitle`(Tmoney 17/800)과 다르다.
  final TextStyle sheetStepTitle;

  /// 일과 시트의 단계 설명 (Figma `963:4237` — Pretendard 13/400).
  /// `cardBody`(15)와 다르다.
  final TextStyle sheetStepBody;
  final TextStyle sheetActionLabel;

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

  /// 로그인 버튼의 `최근 로그인` 알약 (12/w500 Pretendard, Figma `238:1808`).
  /// promptCaption과 값은 같지만 쓰임이 달라 따로 둔다 — 한쪽을 고칠 때
  /// 다른 쪽이 딸려 바뀌면 안 된다.
  final TextStyle lastLoginBadge;

  /// 로그인 화면 구석의 앱 버전 `v1.44.0` (10/w400 Pretendard, #418).
  /// **시안이 없는 개발 쪽 임시값이다.** 알고 찾아야 보일 만큼 작게 둔다 —
  /// caption(12)보다 작은 글자는 이것뿐이다.
  final TextStyle appVersionTag;

  /// 설정 목록 한 줄의 라벨 (16/w400 Pretendard, Figma `1022:4467`).
  ///
  /// `tileLabel`(13/w400 TmoneyRoundWind)과 크기·폰트가 모두 다르다.
  /// 회원탈퇴만 같은 크기에 w500 을 쓴다 — 굵기는 쓰는 쪽에서 얹는다.
  final TextStyle settingsTileLabel;

  /// AI 크레딧 카드 제목 `이번 주 AI 생성` (17/w700 Pretendard, #407 시안).
  final TextStyle creditTitle;

  /// AI 크레딧 남은 숫자 (32/w800 Pretendard). 시안은 37 이지만 설정 목록 폭(361)에 맞춰 줄였다.
  final TextStyle creditNumber;

  /// AI 크레딧 본문 (14/w400 Pretendard). 줄이 꺾일 수 있어 줄 높이를 준다.
  final TextStyle creditBody;

  /// AI 크레딧 작은 안내 (12/w400 Pretendard).
  final TextStyle creditCaption;

  /// 뒤로가기와 같은 줄에 서는 가운데 제목 (18/w600 Pretendard, Figma `1022:4467`).
  ///
  /// 본문 맨 위 큰 제목(`pinTitle` 28/w800 Tmoney)과 **크기·폰트·굵기가 모두 다르다.**
  /// 한쪽을 다른 쪽으로 쓰면 화면 성격이 바뀐다 — 네비게이션 제목과 페이지 제목이다.
  final TextStyle navTitle;

  /// 문의하기 시트 제목 (20/w700 Pretendard, Figma `1045:5005`).
  final TextStyle contactSheetTitle;

  /// 문의하기 시트의 메일 주소 (20/w400 Pretendard).
  /// 제목과 크기가 같지만 굵기가 달라 별개 토큰이다.
  final TextStyle contactSheetEmail;

  /// 행동 카드 제목 (25/w800, style_GKEQ8F).
  /// 순서 배지 숫자용 cardHeadline(30/w800)과 크기가 달라 별개 토큰이다.
  final TextStyle actionCardTitle;

  // --- 공지 팝업 (이슈 #390 · 시안 `팝업` 1090:4922 `방침`) ---
  // 공통 팝업의 변형이다. 버튼 문구는 공통 팝업 `dialogAction` 을 그대로 쓴다.
  // 관리자 미리보기(`notice-preview.js` 맨 위 `APP`)가 같은 값으로 그리므로
  // 여기를 바꾸면 그쪽도 바꾼다 — 어긋나면 미리보기와 앱의 줄바꿈이 달라진다 (#385 A).
  //
  // **자간 0 을 적어 둔다.** 안 적으면 테마 기본 글자(Material 3 bodyMedium)의 자간 0.25 를
  // 물려받아 글이 시안보다 3% 넓어지고, 미리보기(자간 0)와 다른 자리에서 꺾인다 (#390 실측).

  /// 공지 제목 (18/w500 Pretendard · 줄 19.8). `dialogTitle` 과 크기·굵기가 같지만
  /// 줄 간격이 다르다 — 공지 제목은 두 줄이 기본이라 시안이 110% 로 벌렸다.
  final TextStyle noticeTitle;

  /// 공지 본문 (16/w400 Pretendard · 줄 19.2).
  final TextStyle noticeBody;

  /// `일주일간 보지 않기` (14/w400 Pretendard). 설명 최소 14 (docs/08 §7-2).
  final TextStyle noticeHideLabel;

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
    // 약관 전문. 시안(`1027:4831`)이 본문을 **12/w400 · 줄높이 120%** 로 잡는다.
    // 섹션은 시안에 따로 없어 본문과 같은 폭만큼만 내렸다 (16→14).
    docSection: TextStyle(
      fontFamily: promptFontFamily,
      fontSize: 14,
      fontWeight: FontWeight.w700,
      height: 1.2,
    ),
    docBody: TextStyle(
      fontFamily: promptFontFamily,
      fontSize: 12,
      fontWeight: FontWeight.w400,
      height: 1.2,
    ),
    linkCode: TextStyle(
      fontFamily: fontFamily,
      fontSize: 40,
      fontWeight: FontWeight.w800,
      height: 1.0,
    ),
    linkTimer: TextStyle(
      fontFamily: promptFontFamily,
      fontSize: 16,
      fontWeight: FontWeight.w500,
      height: 1.0,
    ),
    linkRetryChip: TextStyle(
      fontFamily: promptFontFamily,
      fontSize: 14,
      fontWeight: FontWeight.w600,
      height: 1.0,
    ),
    dialogTitle: TextStyle(
      fontFamily: promptFontFamily,
      fontSize: 18,
      fontWeight: FontWeight.w500,
      height: 1.0,
    ),
    dialogAction: TextStyle(
      fontFamily: promptFontFamily,
      fontSize: 18,
      fontWeight: FontWeight.w600,
      height: 1.0,
    ),
    linkLater: TextStyle(
      fontFamily: promptFontFamily,
      fontSize: 16,
      fontWeight: FontWeight.w600,
      height: 1.0,
    ),
    helpLink: TextStyle(
      fontFamily: promptFontFamily,
      fontSize: 14,
      fontWeight: FontWeight.w400,
      height: 1.0,
    ),
    loginProvider: TextStyle(
      fontFamily: promptFontFamily,
      fontSize: 18,
      fontWeight: FontWeight.w700,
      height: 1.0,
    ),
    consentAllAgree: TextStyle(
      fontFamily: promptFontFamily,
      fontSize: 20,
      fontWeight: FontWeight.w600,
      height: 1.0,
    ),
    consentBadge: TextStyle(
      fontFamily: promptFontFamily,
      fontSize: 16,
      fontWeight: FontWeight.w600,
      height: 1.0,
    ),
    consentLabel: TextStyle(
      fontFamily: promptFontFamily,
      fontSize: 16,
      fontWeight: FontWeight.w400,
      height: 1.0,
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
    routineTileTitle: TextStyle(
      fontFamily: promptFontFamily,
      fontSize: 16,
      fontWeight: FontWeight.w600,
      height: 1.0,
    ),
    routineTileMeta: TextStyle(
      fontFamily: promptFontFamily,
      fontSize: 13,
      fontWeight: FontWeight.w400,
      height: 1.0,
    ),
    routineTileReward: TextStyle(
      fontFamily: promptFontFamily,
      fontSize: 13,
      fontWeight: FontWeight.w500,
      height: 1.0,
    ),
    routineSectionLabel: TextStyle(
      fontFamily: promptFontFamily,
      fontSize: 14,
      fontWeight: FontWeight.w600,
      height: 1.0,
    ),
    routineCreateLabel: TextStyle(
      fontFamily: promptFontFamily,
      fontSize: 17,
      fontWeight: FontWeight.w500,
      height: 1.0,
    ),
    routineEmptyTitle: TextStyle(
      fontFamily: promptFontFamily,
      fontSize: 16,
      fontWeight: FontWeight.w500,
      height: 1.0,
    ),
    routineEmptyPast: TextStyle(
      fontFamily: promptFontFamily,
      fontSize: 15,
      fontWeight: FontWeight.w500,
      height: 1.0,
    ),
    starsCount: TextStyle(
      fontFamily: fontFamily,
      fontSize: 80,
      fontWeight: FontWeight.w800,
      height: 1.0,
    ),
    stepBadgeNumber: TextStyle(
      fontFamily: fontFamily,
      fontSize: 30,
      fontWeight: FontWeight.w800,
      height: 1.0,
    ),
    sheetTitle: TextStyle(
      fontFamily: promptFontFamily,
      fontSize: 20,
      // 시안(980:4892)은 700 이다. 600 으로 두면 제목이 눈에 띄게 얇다.
      fontWeight: FontWeight.w700,
      height: 1,
    ),
    sheetStepTitle: TextStyle(
      fontFamily: promptFontFamily,
      fontSize: 16,
      fontWeight: FontWeight.w600,
      height: 1,
    ),
    sheetStepBody: TextStyle(
      fontFamily: promptFontFamily,
      fontSize: 13,
      fontWeight: FontWeight.w400,
      height: 1,
    ),
    /// 시트 아래 큰 버튼 글자 (시안 963:4448 `편집하기`).
    ///
    /// **`button`(TmoneyRoundWind)과 다르다.** 같은 버튼 컴포넌트를 쓰는데도
    /// 시안이 시트에서만 Pretendard 로 덮어썼다. 공용 토큰을 고치면 보상 화면
    /// 같은 다른 버튼까지 바뀌므로 시트 전용으로 둔다.
    sheetActionLabel: TextStyle(
      fontFamily: promptFontFamily,
      fontSize: 22,
      fontWeight: FontWeight.w800,
      height: 1,
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
    contactSheetTitle: TextStyle(
      fontFamily: promptFontFamily,
      fontSize: 20,
      fontWeight: FontWeight.w700,
      height: 1.0,
    ),
    contactSheetEmail: TextStyle(
      fontFamily: promptFontFamily,
      fontSize: 20,
      fontWeight: FontWeight.w400,
      height: 1.0,
    ),
    navTitle: TextStyle(
      fontFamily: promptFontFamily,
      fontSize: 18,
      fontWeight: FontWeight.w600,
      height: 1.0,
    ),
    creditTitle: TextStyle(
      fontFamily: promptFontFamily,
      fontSize: 17,
      fontWeight: FontWeight.w700,
      height: 1.2,
    ),
    creditNumber: TextStyle(
      fontFamily: promptFontFamily,
      fontSize: 32,
      fontWeight: FontWeight.w800,
      height: 1.1,
    ),
    creditBody: TextStyle(
      fontFamily: promptFontFamily,
      fontSize: 14,
      fontWeight: FontWeight.w400,
      height: 1.4,
    ),
    creditCaption: TextStyle(
      fontFamily: promptFontFamily,
      fontSize: 12,
      fontWeight: FontWeight.w400,
      height: 1.4,
    ),
    settingsTileLabel: TextStyle(
      fontFamily: promptFontFamily,
      fontSize: 16,
      fontWeight: FontWeight.w400,
      height: 1.0,
    ),
    lastLoginBadge: TextStyle(
      fontFamily: promptFontFamily,
      fontSize: 12,
      fontWeight: FontWeight.w500,
      height: 1.0,
    ),
    appVersionTag: TextStyle(
      fontFamily: promptFontFamily,
      fontSize: 10,
      fontWeight: FontWeight.w400,
      height: 1.0,
    ),
    actionCardTitle: TextStyle(
      fontFamily: fontFamily,
      fontSize: 25,
      fontWeight: FontWeight.w800,
      height: 1.0,
    ),
    noticeTitle: TextStyle(
      fontFamily: promptFontFamily,
      fontSize: 18,
      fontWeight: FontWeight.w500,
      height: 1.1,
      letterSpacing: 0,
    ),
    noticeBody: TextStyle(
      fontFamily: promptFontFamily,
      fontSize: 16,
      fontWeight: FontWeight.w400,
      height: 1.2,
      letterSpacing: 0,
    ),
    noticeHideLabel: TextStyle(
      fontFamily: promptFontFamily,
      fontSize: 14,
      fontWeight: FontWeight.w400,
      height: 1.0,
      letterSpacing: 0,
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
    TextStyle? docSection,
    TextStyle? docBody,
    TextStyle? linkCode,
    TextStyle? linkTimer,
    TextStyle? linkRetryChip,
    TextStyle? dialogTitle,
    TextStyle? dialogAction,
    TextStyle? linkLater,
    TextStyle? helpLink,
    TextStyle? loginProvider,
    TextStyle? consentAllAgree,
    TextStyle? consentBadge,
    TextStyle? consentLabel,
    TextStyle? bodySmall,
    TextStyle? childTileTitle,
    TextStyle? ringPercent,
    TextStyle? routineTileTitle,
    TextStyle? routineTileMeta,
    TextStyle? routineTileReward,
    TextStyle? routineSectionLabel,
    TextStyle? routineCreateLabel,
    TextStyle? routineEmptyTitle,
    TextStyle? routineEmptyPast,
    TextStyle? starsCount,
    TextStyle? stepBadgeNumber,
    TextStyle? sheetTitle,
    TextStyle? sheetStepTitle,
    TextStyle? sheetStepBody,
    TextStyle? sheetActionLabel,
    TextStyle? editChipLabel,
    TextStyle? childDetailTitle,
    TextStyle? promptPlaceholder,
    TextStyle? promptCaption,
    TextStyle? lastLoginBadge,
    TextStyle? appVersionTag,
    TextStyle? settingsTileLabel,
    TextStyle? creditTitle,
    TextStyle? creditNumber,
    TextStyle? creditBody,
    TextStyle? creditCaption,
    TextStyle? navTitle,
    TextStyle? contactSheetTitle,
    TextStyle? contactSheetEmail,
    TextStyle? actionCardTitle,
    TextStyle? noticeTitle,
    TextStyle? noticeBody,
    TextStyle? noticeHideLabel,
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
      docSection: docSection ?? this.docSection,
      docBody: docBody ?? this.docBody,
      linkCode: linkCode ?? this.linkCode,
      linkTimer: linkTimer ?? this.linkTimer,
      linkRetryChip: linkRetryChip ?? this.linkRetryChip,
      dialogTitle: dialogTitle ?? this.dialogTitle,
      dialogAction: dialogAction ?? this.dialogAction,
      linkLater: linkLater ?? this.linkLater,
      helpLink: helpLink ?? this.helpLink,
      loginProvider: loginProvider ?? this.loginProvider,
      consentAllAgree: consentAllAgree ?? this.consentAllAgree,
      consentBadge: consentBadge ?? this.consentBadge,
      consentLabel: consentLabel ?? this.consentLabel,
      bodySmall: bodySmall ?? this.bodySmall,
      childTileTitle: childTileTitle ?? this.childTileTitle,
      ringPercent: ringPercent ?? this.ringPercent,
      routineTileTitle: routineTileTitle ?? this.routineTileTitle,
      routineTileMeta: routineTileMeta ?? this.routineTileMeta,
      routineTileReward: routineTileReward ?? this.routineTileReward,
      routineSectionLabel: routineSectionLabel ?? this.routineSectionLabel,
      routineCreateLabel: routineCreateLabel ?? this.routineCreateLabel,
      routineEmptyTitle: routineEmptyTitle ?? this.routineEmptyTitle,
      routineEmptyPast: routineEmptyPast ?? this.routineEmptyPast,
      starsCount: starsCount ?? this.starsCount,
      stepBadgeNumber: stepBadgeNumber ?? this.stepBadgeNumber,
      sheetTitle: sheetTitle ?? this.sheetTitle,
      sheetStepTitle: sheetStepTitle ?? this.sheetStepTitle,
      sheetStepBody: sheetStepBody ?? this.sheetStepBody,
      sheetActionLabel: sheetActionLabel ?? this.sheetActionLabel,
      editChipLabel: editChipLabel ?? this.editChipLabel,
      childDetailTitle: childDetailTitle ?? this.childDetailTitle,
      promptPlaceholder: promptPlaceholder ?? this.promptPlaceholder,
      promptCaption: promptCaption ?? this.promptCaption,
      lastLoginBadge: lastLoginBadge ?? this.lastLoginBadge,
      appVersionTag: appVersionTag ?? this.appVersionTag,
      settingsTileLabel: settingsTileLabel ?? this.settingsTileLabel,
      creditTitle: creditTitle ?? this.creditTitle,
      creditNumber: creditNumber ?? this.creditNumber,
      creditBody: creditBody ?? this.creditBody,
      creditCaption: creditCaption ?? this.creditCaption,
      navTitle: navTitle ?? this.navTitle,
      contactSheetTitle: contactSheetTitle ?? this.contactSheetTitle,
      contactSheetEmail: contactSheetEmail ?? this.contactSheetEmail,
      actionCardTitle: actionCardTitle ?? this.actionCardTitle,
      noticeTitle: noticeTitle ?? this.noticeTitle,
      noticeBody: noticeBody ?? this.noticeBody,
      noticeHideLabel: noticeHideLabel ?? this.noticeHideLabel,
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
      docSection: TextStyle.lerp(docSection, other.docSection, t)!,
      docBody: TextStyle.lerp(docBody, other.docBody, t)!,
      linkCode: TextStyle.lerp(linkCode, other.linkCode, t)!,
      linkTimer: TextStyle.lerp(linkTimer, other.linkTimer, t)!,
      linkRetryChip:
          TextStyle.lerp(linkRetryChip, other.linkRetryChip, t)!,
      dialogTitle: TextStyle.lerp(dialogTitle, other.dialogTitle, t)!,
      dialogAction: TextStyle.lerp(dialogAction, other.dialogAction, t)!,
      linkLater: TextStyle.lerp(linkLater, other.linkLater, t)!,
      helpLink: TextStyle.lerp(helpLink, other.helpLink, t)!,
      loginProvider: TextStyle.lerp(loginProvider, other.loginProvider, t)!,
      consentAllAgree:
          TextStyle.lerp(consentAllAgree, other.consentAllAgree, t)!,
      consentBadge: TextStyle.lerp(consentBadge, other.consentBadge, t)!,
      consentLabel: TextStyle.lerp(consentLabel, other.consentLabel, t)!,
      bodySmall: TextStyle.lerp(bodySmall, other.bodySmall, t)!,
      childTileTitle: TextStyle.lerp(childTileTitle, other.childTileTitle, t)!,
      ringPercent: TextStyle.lerp(ringPercent, other.ringPercent, t)!,
      routineTileTitle: TextStyle.lerp(routineTileTitle, other.routineTileTitle, t)!,
      routineTileMeta: TextStyle.lerp(routineTileMeta, other.routineTileMeta, t)!,
      routineTileReward: TextStyle.lerp(routineTileReward, other.routineTileReward, t)!,
      routineSectionLabel: TextStyle.lerp(routineSectionLabel, other.routineSectionLabel, t)!,
      routineCreateLabel: TextStyle.lerp(routineCreateLabel, other.routineCreateLabel, t)!,
      routineEmptyTitle: TextStyle.lerp(routineEmptyTitle, other.routineEmptyTitle, t)!,
      routineEmptyPast: TextStyle.lerp(routineEmptyPast, other.routineEmptyPast, t)!,
      starsCount: TextStyle.lerp(starsCount, other.starsCount, t)!,
      stepBadgeNumber: TextStyle.lerp(stepBadgeNumber, other.stepBadgeNumber, t)!,
      sheetTitle: TextStyle.lerp(sheetTitle, other.sheetTitle, t)!,
      sheetStepTitle: TextStyle.lerp(sheetStepTitle, other.sheetStepTitle, t)!,
      sheetStepBody: TextStyle.lerp(sheetStepBody, other.sheetStepBody, t)!,
      sheetActionLabel: TextStyle.lerp(
        sheetActionLabel,
        other.sheetActionLabel,
        t,
      )!,
      editChipLabel: TextStyle.lerp(editChipLabel, other.editChipLabel, t)!,
      childDetailTitle:
          TextStyle.lerp(childDetailTitle, other.childDetailTitle, t)!,
      promptPlaceholder:
          TextStyle.lerp(promptPlaceholder, other.promptPlaceholder, t)!,
      promptCaption: TextStyle.lerp(promptCaption, other.promptCaption, t)!,
      lastLoginBadge: TextStyle.lerp(lastLoginBadge, other.lastLoginBadge, t)!,
      appVersionTag: TextStyle.lerp(appVersionTag, other.appVersionTag, t)!,
      settingsTileLabel:
          TextStyle.lerp(settingsTileLabel, other.settingsTileLabel, t)!,
      creditTitle: TextStyle.lerp(creditTitle, other.creditTitle, t)!,
      creditNumber: TextStyle.lerp(creditNumber, other.creditNumber, t)!,
      creditBody: TextStyle.lerp(creditBody, other.creditBody, t)!,
      creditCaption: TextStyle.lerp(creditCaption, other.creditCaption, t)!,
      navTitle: TextStyle.lerp(navTitle, other.navTitle, t)!,
      contactSheetTitle:
          TextStyle.lerp(contactSheetTitle, other.contactSheetTitle, t)!,
      contactSheetEmail:
          TextStyle.lerp(contactSheetEmail, other.contactSheetEmail, t)!,
      actionCardTitle:
          TextStyle.lerp(actionCardTitle, other.actionCardTitle, t)!,
      noticeTitle: TextStyle.lerp(noticeTitle, other.noticeTitle, t)!,
      noticeBody: TextStyle.lerp(noticeBody, other.noticeBody, t)!,
      noticeHideLabel:
          TextStyle.lerp(noticeHideLabel, other.noticeHideLabel, t)!,
    );
  }
}
