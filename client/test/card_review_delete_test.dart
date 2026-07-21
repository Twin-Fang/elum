import 'package:elum/features/guardian/application/routine_notifier.dart';
import 'package:elum/shared/models/action_card.dart';
import 'package:elum/shared/models/routine.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/test_storage.dart';

/// 카드확인 화면의 삭제 (Figma `보호자_카드확인_수정` 364:8305, 이슈 #69).
///
/// **마지막 한 장은 지울 수 없다.** 카드가 0장이 되면 아이 화면에 보여줄 것이
/// 없어지고, "한 카드에 하나의 행동" 원칙(docs 4번)도 성립하지 않는다.
///
/// 화면(`card_review_screen.dart`)은 `cards.length > 1`일 때만 X 버튼을 주고,
/// notifier도 같은 조건을 다시 확인한다. **두 겹으로 막는다** — 화면이 바뀌어
/// 버튼이 열려도 데이터가 0장이 되지는 않는다.
void main() {
  const cards = [
    ActionCard(id: 'c1', description: '옷을 입어요', stepOrder: 1),
    ActionCard(id: 'c2', description: '우산을 챙겨요', stepOrder: 2),
    ActionCard(id: 'c3', description: '신발을 신어요', stepOrder: 3),
  ];

  ProviderContainer containerWith(List<ActionCard> steps) {
    final container = ProviderContainer(
      overrides: [testStorageOverride(onboardingCompleted: true)],
    );
    addTearDown(container.dispose);

    container.read(routineFlowProvider.notifier).state = RoutineFlowState(
      routine: Routine(id: 'r1', title: '비 오는 날 학교에 가요', steps: steps),
    );
    return container;
  }

  group('카드 삭제 (이슈 #69 · 364:8305)', () {
    test('카드를 지우면 목록에서 빠진다', () {
      final container = containerWith(cards);

      container.read(routineFlowProvider.notifier).removeStep('c2');

      final steps = container.read(routineFlowProvider).routine!.steps;
      expect(steps.map((s) => s.id), ['c1', 'c3']);
    });

    test('마지막 한 장은 지울 수 없다', () {
      // 0장이 되면 아이 화면에 보여줄 것이 없다
      final container = containerWith([cards.first]);

      container.read(routineFlowProvider.notifier).removeStep('c1');

      final steps = container.read(routineFlowProvider).routine!.steps;
      expect(steps, hasLength(1), reason: '마지막 카드는 남아야 한다');
    });

    test('두 장에서 한 장까지는 지워진다', () {
      // 경계값 — 2 → 1은 되고, 1 → 0은 안 된다
      final container = containerWith(cards.take(2).toList());
      final notifier = container.read(routineFlowProvider.notifier);

      notifier.removeStep('c1');
      expect(container.read(routineFlowProvider).routine!.steps, hasLength(1));

      notifier.removeStep('c2');
      expect(
        container.read(routineFlowProvider).routine!.steps,
        hasLength(1),
        reason: '1장 남았으면 더 지울 수 없다',
      );
    });

    test('없는 id를 지워도 목록이 변하지 않는다', () {
      // 화면과 상태가 잠시 어긋나도 죽지 않아야 한다
      final container = containerWith(cards);

      container.read(routineFlowProvider.notifier).removeStep('없는카드');

      expect(container.read(routineFlowProvider).routine!.steps, hasLength(3));
    });

    test('일과가 없으면 삭제해도 죽지 않는다', () {
      final container = ProviderContainer(
        overrides: [testStorageOverride(onboardingCompleted: true)],
      );
      addTearDown(container.dispose);

      expect(
        () => container.read(routineFlowProvider.notifier).removeStep('c1'),
        returnsNormally,
      );
    });
  });
}
