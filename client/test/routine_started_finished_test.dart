import 'package:elum/shared/models/action_card.dart';
import 'package:elum/shared/models/routine.dart';
import 'package:flutter_test/flutter_test.dart';

/// 시작한 일과는 지우지 않고(#533), 다 끝낸 일과는 고치지 않는다(#534).
/// 두 판단이 화면 버튼을 가르므로 서버 규칙과 같은 기준인지 고정한다.
void main() {
  ActionCard card(String id, {bool done = false}) => ActionCard(
    id: id,
    title: id,
    description: id,
    stepOrder: 1,
    completed: done,
  );

  Routine routine({
    String status = 'CONFIRMED',
    int completedStepCount = 0,
    List<ActionCard>? steps,
  }) => Routine(
    id: 'r1',
    status: status,
    completedStepCount: completedStepCount,
    steps: steps ?? [card('a'), card('b')],
  );

  group('hasStarted (#533)', () {
    test('한 단계도 하지 않았으면 시작 전이다 — 지울 수 있다', () {
      expect(routine().hasStarted, isFalse);
    });

  });

  group('isFinished (#534)', () {
    test('서버가 COMPLETED 로 주면 끝냈다', () {
      expect(routine(status: 'COMPLETED').isFinished, isTrue);
    });

  });
}
