import 'package:elum/features/child/application/child_home_entries.dart';
import 'package:elum/shared/models/routine.dart';
import 'package:flutter_test/flutter_test.dart';

/// 이룸이 홈 묶음 상자 (#808).
///
/// 깨지면: 묶음으로 보낸 일과가 낱개로 흩어지거나, 상자 안 순서가 보낸 순서와 달라지거나, 하나만 남은 묶음이 외톨이 상자로 보인다.
void main() {
  Routine routine(
    String id, {
    String? groupId,
    String? groupName,
    int? order,
  }) => Routine(
    id: id,
    title: id,
    sentGroupId: groupId,
    sentGroupName: groupName,
    sentGroupOrder: order,
  );

  test('같은 묶음으로 보낸 일과는 첫 일과 자리에 상자 하나로 묶고 보낸 순서로 정렬한다', () {
    final entries = composeChildHomeEntries([
      routine('낱개 앞'),
      routine('b', groupId: 'g', groupName: '아침', order: 1),
      routine('가운데 낱개'),
      routine('a', groupId: 'g', groupName: '아침', order: 0),
    ]);

    expect(entries.length, 3);
    expect((entries[0] as ChildRoutineEntry).routine.id, '낱개 앞');
    final box = entries[1] as ChildGroupEntry;
    expect(box.groupName, '아침');
    expect(box.routines.map((routine) => routine.id), ['a', 'b']);
    expect((entries[2] as ChildRoutineEntry).routine.id, '가운데 낱개');
  });

  test('오늘 하나만 남은 묶음은 상자 없이 낱개 한 줄로 둔다', () {
    final entries = composeChildHomeEntries([
      routine('a', groupId: 'g', groupName: '아침', order: 0),
    ]);

    expect(entries.single, isA<ChildRoutineEntry>());
  });
}
