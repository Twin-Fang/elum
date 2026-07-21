import '../../../shared/models/action_card.dart';
import '../../onboarding/domain/support_goal.dart';

/// fallback용 카드 세트.
///
/// 데모 시나리오는 docs/README.md의 페르소나(하늘이 · 비 오는 날 학교 가기)를 따른다.
abstract final class DemoCards {
  /// 최종 fallback — 순수 상수라 어떤 상황에서도 실패하지 않는다.
  static const List<ActionCard> rainySchoolDay = [
    ActionCard(id: 'demo-1', description: '옷을 입어요', stepOrder: 1),
    ActionCard(id: 'demo-2', description: '가방을 챙겨요', stepOrder: 2),
    ActionCard(id: 'demo-3', description: '우산을 챙겨요', stepOrder: 3),
    ActionCard(id: 'demo-4', description: '장화를 신어요', stepOrder: 4),
    ActionCard(id: 'demo-5', description: '우산을 쓰고 학교에 가요', stepOrder: 5),
  ];

  /// 준비물 목표를 선택했을 때 쓰는 세트 — 챙길 것을 더 구체적으로 나눈다.
  static const List<ActionCard> rainySchoolDayWithItems = [
    ActionCard(id: 'demo-1', description: '긴팔 옷과 긴 바지를 입어요', stepOrder: 1),
    ActionCard(id: 'demo-2', description: '필통과 숙제를 가방에 넣어요', stepOrder: 2),
    ActionCard(id: 'demo-3', description: '우산을 챙겨요', stepOrder: 3),
    ActionCard(id: 'demo-4', description: '장화를 신어요', stepOrder: 4),
    ActionCard(id: 'demo-5', description: '우산을 쓰고 학교에 가요', stepOrder: 5),
  ];

  /// 2차 fallback — 선택한 도움 목표를 반영해 카드를 조정한다.
  ///
  /// 서버 없이도 "목표에 따라 결과가 달라진다"는 서비스 특성이 드러나야 한다.
  static List<ActionCard> forGoals(Set<SupportGoal> goals) {
    if (goals.contains(SupportGoal.prepareItems)) {
      return rainySchoolDayWithItems;
    }
    return rainySchoolDay;
  }
}
