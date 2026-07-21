import '../../features/child/domain/reward_character.dart';
import '../../features/onboarding/domain/character.dart';

/// 에셋 경로 상수.
///
/// 위젯에 `'assets/images/...'` 문자열을 직접 쓰지 않는다.
/// 오타는 런타임에야 드러나고, 파일명이 바뀌면 어디를 고쳐야 할지 알 수 없다.
///
/// 에셋을 추가하면 (1) 이 파일 (2) pubspec.yaml `assets:` 를 함께 수정한다.
abstract final class AppAssets {
  static const _images = 'assets/images';

  /// 도움 목표 아이콘 (40×40). Figma `온보딩_목표` 프레임의 Group 5~8.
  ///
  /// **목표별로 다르지 않다.** 네 그룹 모두 노란 반투명 원 + `fi-br-child-head`
  /// 조합으로 Figma상 완전히 동일하다. 목표마다 다른 아이콘을 쓰려면
  /// 디자이너가 Figma를 먼저 바꿔야 한다. (이슈 #11)
  static const goalIcon = '$_images/goal_icon.svg';

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

  /// 우상단 캐릭터 배지 (56×56 영역). Figma 217:2670 Mask group.
  static const homeCharacterBadge = '$_images/home_character_badge.svg';

  /// "새로운 일과 만들기" 카드 속 일러스트 (56×56 영역). Figma 217:2675.
  static const homeNewRoutineIllust = '$_images/home_new_routine_illust.svg';

  /// 최근 일과 빈 상태 일러스트 (40×40 영역). Figma 217:2695.
  static const homeEmptyIllust = '$_images/home_empty_illust.svg';

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
  /// 테두리 없는 [characterBadgeRuru]를 쓰면 캐릭터만 덩그러니 뜬다.
  static String characterBadgeFramed(CardCharacter character) =>
      switch (character) {
        CardCharacter.cat => '$_images/character_badge_framed_ruru.svg',
        CardCharacter.fox => '$_images/character_badge_framed_popo.svg',
      };

  /// 완료 체크 (10×10). Figma `fi-br-check`.
  /// 로딩 화면의 단계별 완료 표시에 쓴다.
  static const iconCheck = '$_images/icon_check.svg';

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
  static const splashChickBody = '$_images/splash_chick_body.svg';

  /// 몸통 하단 페이드 (393×177)
  static const splashFade = '$_images/splash_fade.svg';

  /// 새싹 줄기 (113×111)
  static const splashHill = '$_images/splash_hill.svg';

  /// 반짝이는 별 (36×34 영역)
  static const splashStar = '$_images/splash_star.svg';

  /// 언덕 위 캐릭터 실루엣 (각 30×32)
  static const splashCharLeft = '$_images/splash_char_left.svg';
  static const splashCharRight = '$_images/splash_char_right.svg';

  /// 가운데 장식 (45×25)
  static const splashCenter = '$_images/splash_center.svg';

  // --- 홈 일과 목록 (Figma 356:4688 / 356:5079 / 343:4543 / 364:8219) ---

  /// 일과 접기/펼치기 화살표 (24×24). Figma `fi-br-angle-small-up`(356:4862).
  /// 원본이 아래 방향이다 — 펼침 상태에서는 180° 돌려 위를 향하게 한다.
  /// 아이 홈에서는 90° 돌려 `>`로 쓴다.
  static const iconAngleSmall = '$_images/icon_angle_small_up.svg';

  /// 아이 홈 상단 별 배지 (50×48). Figma 364:8531 `Group 44`.
  /// 숫자는 SVG에 없다 — 코드에서 겹쳐 그린다.
  static const starBadge = '$_images/star_badge.svg';

  /// 아이 홈 빈 상태의 시무룩한 루루 (164×164). Figma 382:3220 `루루_슬픔`.
  static const ruruSad = '$_images/ruru_sad.svg';

  /// 아이 홈 빈 상태의 시무룩한 포포 (164×164). 여우 캐릭터를 골랐을 때 쓴다.
  static const popoSad = '$_images/popo_sad.svg';

  /// 아이_별 화면 가운데 큰 별 (299×299 영역). Figma 364:8282 `Group 46`.
  static const starBig = '$_images/star_big.svg';

  /// 아이_별 화면 주변 작은 별 7개. Figma 364:8227~8228 `Star 4~10`.
  /// index는 1부터 — Figma 배치 좌표와 함께 쓴다.
  static String starDeco(int index) => '$_images/star_deco_$index.svg';
}
