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

  // --- 입력 필드 아이콘 ---

  /// 아이 이름 입력 필드의 좌측 아이콘 (40×40).
  /// 노란 원 배경(rgba(255,214,41,0.3))과 어린이 머리(#F3C500)가 SVG 안에 함께 있다.
  /// Figma `온보딩_이름`(204:991)의 Group 5.
  ///
  /// 현재 [goalIcon]과 그림이 같지만 상수를 분리해 둔다. 쓰이는 자리가 다르고
  /// (목표 칩 vs 이름 입력 필드) 한쪽만 교체될 수 있다.
  static const inputFieldIconChildName = '$_images/icon_child_head.svg';

  /// 캐릭터 일러스트 (약 164×164). 카드 속 주인공으로도 쓰인다.
  static String character(CardCharacter character) => switch (character) {
        CardCharacter.cat => '$_images/character_cat.svg',
        CardCharacter.fox => '$_images/character_fox.svg',
      };

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
}
