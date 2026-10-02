import 'package:elum/features/child/application/child_routine_notifier.dart';
import 'package:elum/features/child/domain/routine_progress_record.dart';
import 'package:elum/features/guardian/presentation/widgets/today_routine_section.dart';
import 'package:elum/shared/models/action_card.dart';
import 'package:elum/shared/models/routine.dart';
import 'package:flutter_test/flutter_test.dart';

/// 홈 진행률은 서버에 못 보낸 체크가 있을 때만 기기 기록을 따른다.
/// 다 보낸 뒤에도 기록을 따르면 다른 휴대폰이 끝낸 카드가 반영되지 않는다.
void main() {
  ActionCard card(String id, {bool completed = false}) =>
      ActionCard(id: id, description: id, stepOrder: 1, completed: completed);

  Routine routineOf(String id, List<ActionCard> steps) =>
      Routine(id: id, title: '일과', status: 'CONFIRMED', steps: steps);

  // 이 휴대폰에는 카드 1, 2를 체크한 기록만 있다
  final localOnly12 = RoutineProgressRecord(completed: {'c1', 'c2'});

  test('다 보낸 일과는 다른 휴대폰이 끝낸 카드까지 서버 값으로 센다', () {
    final routine = routineOf('r1', [
      card('c1', completed: true),
      card('c2', completed: true),
      card('c3', completed: true),
    ]);
    final state = ChildRoutineState(progress: {'r1': localOnly12});

    expect(routineProgress(routine, state), 1.0);
  });

  test('아직 못 보낸 체크가 있으면 기기 기록이 기준이다', () {
    final routine = routineOf('r1', [card('c1'), card('c2'), card('c3')]);
    final state = ChildRoutineState(
      progress: {'r1': localOnly12},
      pending: {'r1'},
    );

    expect(routineProgress(routine, state), closeTo(2 / 3, 0.001));
  });

  test('서버에 올리지 않는 로컬 일과는 늘 기기 기록이 기준이다', () {
    final routine = routineOf('local', [card('c1'), card('c2'), card('c3')]);
    final state = ChildRoutineState(progress: {'local': localOnly12});

    expect(routineProgress(routine, state), closeTo(2 / 3, 0.001));
  });
}
