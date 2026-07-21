import '../../../shared/models/action_card.dart';
import '../../onboarding/domain/support_goal.dart';

/// fallback용 카드 세트.
///
/// 데모 시나리오는 docs/README.md의 페르소나(하늘이 · 비 오는 날 학교 가기)를 따른다.
abstract final class DemoCards {
  /// 최종 fallback — 순수 상수라 어떤 상황에서도 실패하지 않는다.
  ///
  /// 문구는 Figma `보호자_홈_최근일과`(309:3739) 원본이다. 서버가 불안정한
  /// 동안 이 카드로 화면을 확인하므로 디자인과 같아야 한다. (이슈 #34)
  static const List<ActionCard> rainySchoolDay = [
    ActionCard(
      id: 'demo-1',
      title: '옷을 입어요',
      description: '학교에 갈 옷을 차례대로 입어요',
      stepOrder: 1,
    ),
    ActionCard(
      id: 'demo-2',
      title: '여벌 양말을 챙겨요',
      description: '가방에 여벌 양말을 넣어요',
      stepOrder: 2,
    ),
    ActionCard(
      id: 'demo-3',
      title: '우비를 입어요',
      description: '비에 젖지 않도록 우비를 입어요',
      stepOrder: 3,
    ),
    ActionCard(
      id: 'demo-4',
      title: '우산을 챙겨요',
      description: '현관에서 우산을 챙겨요',
      stepOrder: 4,
    ),
    ActionCard(
      id: 'demo-5',
      title: '천천히 학교로 가요',
      description: '비 오는 길에서는 천천히 걸어요',
      stepOrder: 5,
    ),
  ];

  /// 준비물 목표를 선택했을 때 쓰는 세트 — 챙길 것을 더 구체적으로 나눈다.
  static const List<ActionCard> rainySchoolDayWithItems = [
    ActionCard(
      id: 'demo-1',
      title: '옷을 입어요',
      description: '긴팔 옷과 긴 바지를 차례대로 입어요',
      stepOrder: 1,
    ),
    ActionCard(
      id: 'demo-2',
      title: '가방을 챙겨요',
      description: '필통과 숙제를 가방에 넣어요',
      stepOrder: 2,
    ),
    ActionCard(
      id: 'demo-3',
      title: '우산을 챙겨요',
      description: '현관에서 우산을 챙겨요',
      stepOrder: 3,
    ),
    ActionCard(
      id: 'demo-4',
      title: '장화를 신어요',
      description: '비 오는 날에는 장화를 신어요',
      stepOrder: 4,
    ),
    ActionCard(
      id: 'demo-5',
      title: '천천히 학교로 가요',
      description: '우산을 쓰고 천천히 걸어가요',
      stepOrder: 5,
    ),
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
