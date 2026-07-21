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
}
