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

  /// 도움 목표 아이콘 (40×40). Figma `온보딩_목표` 프레임의 Group 5~8.
  static String goalIcon(SupportGoal goal) => switch (goal) {
        SupportGoal.stepByStep => '$_images/goal_step_by_step.svg',
        SupportGoal.prepareItems => '$_images/goal_prepare_items.svg',
        SupportGoal.prepareNew => '$_images/goal_prepare_new.svg',
        SupportGoal.independent => '$_images/goal_independent.svg',
      };

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
