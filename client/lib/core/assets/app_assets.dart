import '../../features/child/domain/reward_character.dart';
import '../../features/onboarding/domain/character.dart';
import '../../features/onboarding/domain/support_goal.dart';

/// 에셋 경로 상수.
///
/// 위젯에 `'assets/images/...'` 문자열을 직접 쓰지 않는다.
/// 오타는 런타임에야 드러나고, 파일명이 바뀌면 어디를 고쳐야 할지 알 수 없다.
///
/// 에셋을 추가하면 (1) 이 파일 (2) pubspec.yaml `assets:` 를 함께 수정한다.
abstract final class AppAssets {
  static const _images = 'assets/images';

  /// 소셜 로그인 제공자 로고 (22×22). Figma `로그인`(238:1808)에서 받았다.
  ///
  /// **각 사의 브랜드 자산이다.** 색·비율을 바꾸면 제공자 검수·스토어 심사에서
  /// 지적받는다. 파일을 열어 색을 고치지 않는다 (이슈 #230).
  static const _loginIcons = 'assets/icon/login';
  static const loginKakao = '$_loginIcons/kakao.svg';
  static const loginNaver = '$_loginIcons/naver.svg';
  static const loginApple = '$_loginIcons/apple.svg';

  /// 공통 팝업의 성공 아이콘 (40×40 원 + 흰 체크). Figma `채크_라운드`(726:4882).
  /// 원과 체크가 한 파일에 있어 크기만 바꿔 쓰면 된다.
  static const dialogCheck = 'assets/icon/dialog/check_round.svg';

  /// 공통 팝업의 경고 아이콘 (40×40 원 + 흰 느낌표). 이슈 #242.
  ///
  /// **빨강이 아니라 노랑이다.** 아동도 볼 수 있는 화면이라 붉은 경고를 쓰지
  /// 않는다 (client/CLAUDE.md). `danger`(되돌릴 수 없음)와 그래서 색이 다르다.
  static const dialogWarn = 'assets/icon/dialog/warn_round.svg';

  /// 공통 팝업의 삭제 아이콘 (40×40 붉은 원 + 흰 휴지통). Figma 931:4877.
  ///
  /// **여기만 붉다.** 경고(dialogWarn)는 노랑이지만 삭제는 되돌릴 수 없어
  /// 색으로 먼저 멈춰 세운다. 보호자 화면에만 쓴다.
  static const dialogTrash = 'assets/icon/dialog/trash_round.svg';

  /// 도움 목표 아이콘 (40×40). Figma `온보딩_목표`(204:1002)의 Group 62~65,
  /// 목표별로 서로 다른 아이콘이다 (2026-07-22 갱신, 이슈 #11 후속).
  /// 목표 칩 아이콘 (40×40).
  ///
  /// **고른 뒤에는 배경 원 색이 바뀐다** — 미선택 `#EEE9E6`, 선택 `#93DBCC`
  /// (Figma `204:1002` ↔ `204:1147`). 원이 그림 안에 들어 있어 코드로 덧칠할 수
  /// 없으므로 두 벌을 따로 들여온다. 한 벌만 쓰면 고른 칩만 원이 허옇게 남는다 (#297).
  static String goalIcon(SupportGoal goal, {bool selected = false}) {
    final suffix = selected ? '_selected' : '';
    return switch (goal) {
      SupportGoal.stepByStep => '$_images/goal_icon_step_by_step$suffix.svg',
      SupportGoal.prepareItems => '$_images/goal_icon_prepare_items$suffix.svg',
      SupportGoal.prepareNew => '$_images/goal_icon_prepare_new$suffix.svg',
      SupportGoal.independent => '$_images/goal_icon_independent$suffix.svg',
    };
  }

  /// 역할 선택 카드 그림 (40×40) — ⚠️ **임시로 목표 아이콘을 빌려 쓴다.**
  ///
  /// 전용 그림 2종은 아직 없다 (#198 D1 🎨 `역할 선택 그림 2`). 도형을 코드로
  /// 그리지 않기 위한 대타이므로, 에셋이 나오면 **이 두 줄만** 바꾸면 된다.
  static const roleGuardianMock = '$_images/goal_icon_step_by_step.svg';
  static const roleElumiMock = '$_images/goal_icon_independent.svg';

  /// 뒤로가기 (24×24). Figma `fi-br-angle-left`.
  /// Material 아이콘은 형태가 달라 쓰지 않는다.
  static const iconBack = '$_images/icon_back.svg';

  /// 맞춤설정완료 전환 화면의 아이콘 (78×78).
  /// Figma `온보딩_맞춤설정완료`(204:1042)의 Group 5.
  static const setupDoneIcon = '$_images/setup_done_icon.svg';

  // --- 입력 필드 아이콘 ---

  /// 캐릭터 일러스트 (약 164×164). 카드 속 주인공으로도 쓰인다.
  static String character(CardCharacter character) => switch (character) {
        CardCharacter.cat => '$_images/character_cat.svg',
        CardCharacter.fox => '$_images/character_fox.svg',
      };

  // --- 보호자 홈 (Figma `보호자_홈` 217:2655) ---

  /// 상단 로고 (80×30). 시작 화면 로고(164×60)와 크기가 달라 따로 받았다.
  static const homeLogo = '$_images/logo_elum_home.svg';

  /// 섹션 제목 앞 반짝임 (15×18). Figma `sparkles`.
  static const iconSparkles = '$_images/icon_sparkles.svg';

  /// 홈으로 돌아가기 (24×24). Figma `fi-br-home`.
  /// 일과 만들기 흐름에서 뒤로가기 옆에 함께 놓인다.
  static const iconHome = '$_images/icon_home.svg';

  /// 카드 읽어주기 (25×25). Figma `fi-br-volume`.
  static const iconVolume = '$_images/icon_volume.svg';

  /// 카드확인의 카드 삭제 버튼 (30×30 — 흐린 원 + X).
  /// Figma 393:4010 (262:5124 이미지 우상단, 2026-07-22 덤프).
  static const iconCardDelete = '$_images/icon_card_delete.svg';

  /// 아이 홈의 체크 버튼 (88×88). 체크 전 빈 원.
  static const childCheckEmpty = '$_images/child_check_empty.svg';

  /// 완료 체크 배지 (40×40). 홈 일과 목록의 완료 표시.
  static const iconCheckDone = '$_images/icon_check_done.svg';

  /// 보상 화면의 포포 일러스트 (117×104). Figma 334:4433.
  static const rewardPopo = '$_images/reward_popo.svg';

  /// 보상 화면의 루미 일러스트 (124.7×114). Figma 309:4055.
  static const rewardLumi = '$_images/reward_lumi.svg';

  /// 보상 화면의 루루 일러스트 (122.7×97.6). Figma 343:4434.
  static const rewardRuru = '$_images/reward_ruru.svg';

  /// 보상 캐릭터 → 일러스트. switch라 새 캐릭터 추가 시 컴파일 에러로 잡힌다.
  static String rewardCharacter(RewardCharacter character) =>
      switch (character) {
        RewardCharacter.lumi => rewardLumi,
        RewardCharacter.popo => rewardPopo,
        RewardCharacter.ruru => rewardRuru,
      };

  /// 아이 홈 우측 상단 캐릭터 배지 (68×68). **테두리가 없는 맨 일러스트다.**
  @Deprecated('테두리가 빠져 있다. characterBadgeFramed를 쓴다.')
  static const characterBadgeRuru = '$_images/character_badge_ruru.svg';

  /// 아이 홈 우측 상단 캐릭터 배지 (56×56). Figma 356:5106(고양이) · 382:3257(여우).
  ///
  /// 둥근 사각형 테두리 + 배경까지 포함한다. 캐릭터마다 **색이 다르다** —
  /// 고양이는 파랑(#9CADF1 / #CED8FF), 여우는 주황(#EB9B73 / #FFDAC7).
  /// 테두리 없는 `characterBadgeRuru`를 쓰면 캐릭터만 덩그러니 뜬다.
  static String characterBadgeFramed(CardCharacter character) =>
      switch (character) {
        CardCharacter.cat => '$_images/character_badge_framed_ruru.svg',
        CardCharacter.fox => '$_images/character_badge_framed_popo.svg',
      };

  /// 보호자 홈 "새로운 일과 만들기" 카드 아이콘 (47×51). Figma 217:2675.
  ///
  /// 보호자가 고른 캐릭터(고양이/여우)와 무관하게 **AI 마스코트 "루미" 병아리로 고정**이다.
  /// (이슈 #110 — 기존엔 [characterBadgeFramed]를 잘못 재사용하고 있었다)
  static const homeNewRoutineChick = '$_images/home_new_routine_chick.svg';

  /// 완료 체크 (10×10). Figma `fi-br-check`.
  /// 로딩 화면의 단계별 완료 표시에 쓴다.
  static const iconCheck = '$_images/icon_check.svg';

  /// 동그란 체크 안의 **체크 표시만** (Figma `채크_라운드` 726:4866).
  ///
  /// `Icons.check` 글리프를 쓰면 안 된다 — 시안의 체크는 가로로 긴 벡터라
  /// 정사각 글리프와 모양이 다르다. 20 기준으로 10.91×8.13 이다.
  static const iconCheckMark = '$_images/icon_check_mark.svg';

  /// 일과 만들기 화면 상단의 큰 반짝임 (30×36).
  /// Figma `보호자_새로운 일과 만들기`(238:1643)의 `sparkles`(238:1784).
  /// [iconSparkles]와 크기·비율이 달라 따로 받았다.
  static const iconSparklesLarge = '$_images/icon_sparkles_large.svg';

  /// 최근 일과 섹션 제목 앞 시계 (18×18). Figma `fi-br-clock`.
  static const iconClock = '$_images/icon_clock.svg';

  /// "secured by ELUM AI DLP" 배지의 자물쇠 (16×16). Figma `Component 7`(418:4049).
  static const iconDlpLock = '$_images/icon_dlp_lock.svg';

  /// 준비 로딩 화면의 루미 캐릭터 (Figma 262:4569 `Group 26`, 122×123).
  ///
  /// **`prepare` 화면에만 있다** — 카드 생성 로딩(262:4703)에는 없다.
  /// 화면 왼쪽 밖(x=-48)에 걸쳐 몸통 일부만 보인다.
  static const lumiThinking = '$_images/lumi_thinking.svg';

  /// 로딩 체크리스트의 완료 표시 (20×20). Figma 262:4692 `Group 27`.
  static const stageCheckDone = '$_images/stage_check_done.svg';

  /// 로딩 체크리스트의 미완료 표시 (20×20). Figma 262:4698 `Ellipse 22` —
  /// 채움 없이 테두리만 있는 원(rgba(36,38,52,0.6) 3px).
  static const stageCheckPending = '$_images/stage_check_pending.svg';

  // --- 시작 화면 (Figma `시작` 238:1808) ---

  /// 이룸 로고 (164×60). Cloudsofa_namgim 폰트 대신 이 SVG를 쓴다.
  static const logo = '$_images/logo_elum.svg';

  /// 병아리 몸통 (393×439). 둥근 형태 + 방사형 그라데이션이 SVG에 포함되어 있다.
  /// 직접 그리지 않고 이 파일을 그대로 쓴다.
  /// 병아리 몸통 (Figma `726:4743` — 393×439).
  ///
  /// **PNG다.** 방사형 그라데이션에 `gradientTransform` 행렬이 걸려 있어
  /// 렌더러가 그대로 그리지 못한다 — 아래쪽 민트가 훨씬 옅게 나와 몸이
  /// 33 짧아 보였다 (#297). 필터를 버리는 것과 같은 부류다.
  static const splashChickBody = '$_images/splash_chick_body.png';

  /// 몸통 하단 페이드 (393×177)
  static const splashFade = '$_images/splash_fade.svg';

  /// 새싹 줄기 (113×111)
  static const splashHill = '$_images/splash_hill.svg';

  /// 반짝이는 별 (36×34 영역)
  /// 새싹 줄기 끝 청록 구슬 (Figma `726:4744` — 본체 36×34 + 둘레 빛 blur 30).
  ///
  /// **PNG다.** 빛이 SVG `<filter>`라 렌더러가 통째로 버린다. 상자는 96×94이고
  /// 본체가 그 안 (30, 30)에 있다 — 본체를 시안 자리(67, 340)에 두려면
  /// 상자를 (37, 310)에 놓는다 (#297).
  static const splashOrb = '$_images/splash_orb.png';

  @Deprecated('빛이 빠진다. splashOrb(PNG)를 쓴다.')
  static const splashStar = '$_images/splash_star.svg';

  /// 병아리 **눈** (각 30×32) — 지금 시안에는 없다.
  ///
  /// 시안 `726:4942`(background_graphic) 안에는 벡터가 셋뿐이다 — 줄기·몸통·구슬.
  /// 얼굴은 2026-07-21 옛 시안에서 받아 둔 것이고, 그 뒤 시안에서 빠졌다.
  /// 로그인 화면에서 부리가 카카오 버튼 아래로 13 삐져나와 드러났다 (#297).
  @Deprecated('지금 시안에 없는 얼굴이다. 되살리려면 시안에 먼저 그려야 한다.')
  static const splashCharLeft = '$_images/splash_char_left.svg';
  @Deprecated('지금 시안에 없는 얼굴이다. 되살리려면 시안에 먼저 그려야 한다.')
  static const splashCharRight = '$_images/splash_char_right.svg';

  /// 병아리 **부리** (45×25) — 지금 시안에는 없다. [splashCharLeft] 참조.
  @Deprecated('지금 시안에 없는 얼굴이다. 되살리려면 시안에 먼저 그려야 한다.')
  static const splashCenter = '$_images/splash_center.svg';

  /// 이룸이 카드의 **체크 표시** (Figma `993:4331` — 48×35.76).
  ///
  /// `Icons.check_rounded`를 쓰고 있었는데 획이 훨씬 가늘다. 시안과 나란히 놓고
  /// 진한 픽셀을 세면 607 대 212였다. 색은 상태에 따라 바뀌므로 덧칠한다 (#297).
  static const childCheckMark = '$_images/child_check_mark.svg';

  /// 일과 시트 행의 **순서 바꾸기 손잡이** (Figma `963:4240` 순서변경 — 18×18).
  ///
  /// `Icons.drag_handle`을 쓰고 있었는데 그건 **줄이 둘**이다. 시안은 셋이고
  /// 색도 `#CACACA`로 더 진하다. 나란히 놓고 보기 전에는 안 드러났다 (#297).
  static const sheetReorderHandle = '$_images/sheet_reorder_handle.svg';

  // --- 홈 일과 목록 (Figma 356:4688 / 356:5079 / 343:4543 / 364:8219) ---

  /// 일과 접기/펼치기 화살표 (24×24). Figma `fi-br-angle-small-up`(356:4862).
  /// 원본이 아래 방향이다 — 펼침 상태에서는 180° 돌려 위를 향하게 한다.
  /// 아이 홈에서는 90° 돌려 `>`로 쓴다.
  static const iconAngleSmall = '$_images/icon_angle_small_up.svg';

  /// 일과를 밀었을 때 나오는 삭제 아이콘 (24×24, 흰색). Figma `fi-br-trash`(384:3479).
  static const iconTrash = '$_images/icon_trash.svg';

  /// 같은 자리의 수정 아이콘 (24×24, 흰색). Figma `fi-br-pencil`(931:4364).
  static const iconPencil = '$_images/icon_pencil.svg';

  /// `지난 일과` 섹션 제목 아이콘 (18×18). Figma `fi-br-time-forward`(931:3867).
  static const iconTimePast = '$_images/icon_time_past.svg';

  /// `오늘 일과` 섹션 제목 아이콘 (18×18). Figma `오늘일과`(931:3880).
  ///
  /// **[iconClock]과 다른 파일이다.** 저쪽은 파랑(#9CADF1), 이쪽은 섹션
  /// 라벨과 같은 회색(#74757D)이다. 모양이 같아 재사용했다가 색이 어긋난 채
  /// 배포됐다 — 시안과 픽셀로 맞대보고서야 드러났다 (이슈 #258).
  static const iconTodayRoutine = '$_images/icon_today_routine.svg';

  /// 홈 우상단 설정 톱니 (24×24). Figma `설정`(781:5992).
  ///
  /// **Material 아이콘으로 대신하지 않는다.** 시안의 톱니는 날이 8개고
  /// 가운데 구멍이 크다 — Material `settings_outlined`와 모양이 다르다.
  static const iconSettings = '$_images/icon_settings.svg';

  /// 아이 홈 상단 별 배지 (50×48). Figma 364:8531 `Group 44`.
  /// 숫자는 SVG에 없다 — 코드에서 겹쳐 그린다.
  static const starBadge = '$_images/star_badge.svg';

  /// 일과 시트 보상 뱃지 안의 별 (Figma 963:4442, 25×24).
  static const rewardBadgeStar = '$_images/reward_badge_star.svg';

  /// 아이 홈 빈 상태의 시무룩한 루루 (164×164). Figma 382:3220 `루루_슬픔`.
  static const ruruSad = '$_images/ruru_sad.svg';

  /// 아이 홈 빈 상태의 시무룩한 포포 (164×164). 여우 캐릭터를 골랐을 때 쓴다.
  static const popoSad = '$_images/popo_sad.svg';

  /// 아이_별 화면 가운데 큰 별. Figma 364:8282 `Group 46` · 실제 264×255.
  ///
  /// **PNG인 이유** ⚠️ — 이 별은 세 겹(후광·그림자·안쪽 하이라이트)으로 되어 있고
  /// 세 겹이 전부 SVG `filter`다. **flutter_svg는 filter를 통째로 버린다**
  /// (`unhandled element <filter/>`). 그러면 맨 뒤의 후광용 반투명 별이 흐려지지
  /// 않고 그대로 깔려, 별 둘레에 탁한 올리브색 띠가 생긴다 — 시안의 흰빛 도는
  /// 얇은 테두리와 전혀 다르게 보인다. 필터가 구워진 PNG를 쓴다 (#297).
  ///
  /// Figma가 알려주는 배치 크기(299×299)는 **필터까지 포함한 상자**라 실제
  /// 그림보다 크다. 에셋을 늘리지 말고 원본 크기 그대로 놓는다.
  static const starBig = '$_images/star_big.png';

  /// 아이_별 화면 주변 작은 별 7개. Figma 364:8227~8228 `Star 4~10`.
  /// index는 1부터 — Figma 배치 좌표와 함께 쓴다.
  ///
  /// 큰 별과 같은 이유로 PNG다. **투명도가 이미 구워져 있다** — 시안이 0.3으로
  /// 둔 별은 알파가 76으로 나온다. 위에 `Opacity`를 한 번 더 씌우면 두 번
  /// 곱해져 시안보다 옅어진다.
  static String starDeco(int index) => '$_images/star_deco_$index.png';

  /// 보상 화면 큰 별 옆에 뜨는 작은 별 둘 (Figma `334:4293` 초록 · `334:4294` 보라).
  ///
  /// **별 모으기 화면의 `starDeco`와 다른 노드다.** 그쪽 초록별은 40%만 불투명해
  /// 어두운 보상 배경에 올리면 시커멓게 죽는다. 실제로 그걸 돌려 쓰고 있었다 (#297).
  /// 후광(`boxShadow 0 0 10px`)이 구워진 PNG라 렌더러가 버리지 않는다.
  static const rewardStarGreen = '$_images/reward_star_green.png';
  static const rewardStarPurple = '$_images/reward_star_purple.png';
}
