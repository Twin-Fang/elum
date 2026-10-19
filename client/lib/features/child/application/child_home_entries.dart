import 'package:flutter/foundation.dart';

import '../../../shared/models/routine.dart';

/// 이룸이 홈 목록 한 칸: 낱개 일과 한 줄 또는 묶음 상자 (#808)
@immutable
sealed class ChildHomeEntry {
  const ChildHomeEntry();
}

class ChildRoutineEntry extends ChildHomeEntry {
  const ChildRoutineEntry(this.routine);

  final Routine routine;
}

class ChildGroupEntry extends ChildHomeEntry {
  const ChildGroupEntry({
    required this.groupId,
    required this.groupName,
    required this.routines,
  });

  final String groupId;

  /// 보낼 때의 묶음 이름 (나중에 이름을 바꿔도 그날 상자는 보낸 때 모양)
  final String groupName;

  /// 묶음 순서대로 정렬한 오늘 일과 (2개 이상)
  final List<Routine> routines;
}

/// 오늘 일과 > 홈 목록 칸: 같은 묶음으로 보낸 일과는 상자 하나로, 나머지는 낱개 한 줄
///
/// 상자는 묶음의 첫 일과가 있던 자리에 놓고, 안의 줄은 보낸 순서(sentGroupOrder)로 정렬한다.
/// 같은 묶음 일과가 오늘 하나만 남았으면(다른 건 지움·승인 전) 상자 없이 낱개로 둔다.
List<ChildHomeEntry> composeChildHomeEntries(List<Routine> routines) {
  final membersByGroupId = <String, List<Routine>>{};
  for (final routine in routines) {
    final groupId = routine.sentGroupId;
    if (groupId == null) continue;
    membersByGroupId.putIfAbsent(groupId, () => []).add(routine);
  }

  final placedGroupIds = <String>{};
  final entries = <ChildHomeEntry>[];
  for (final routine in routines) {
    final groupId = routine.sentGroupId;
    final members = groupId == null ? null : membersByGroupId[groupId];
    if (groupId == null || members == null || members.length < 2) {
      entries.add(ChildRoutineEntry(routine));
      continue;
    }
    // 묶음의 첫 일과 자리에서 상자를 한 번만 만든다
    if (!placedGroupIds.add(groupId)) continue;
    final sortedMembers = [...members]
      ..sort(
        (first, second) =>
            (first.sentGroupOrder ?? 0).compareTo(second.sentGroupOrder ?? 0),
      );
    entries.add(
      ChildGroupEntry(
        groupId: groupId,
        groupName: routine.sentGroupName ?? '',
        routines: sortedMembers,
      ),
    );
  }
  return entries;
}
