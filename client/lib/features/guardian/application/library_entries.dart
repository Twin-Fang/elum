import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/models/routine.dart';
import '../domain/routine_group.dart';
import 'routine_providers.dart';

/// 일과관리 격자 한 칸: 낱개 원본 또는 묶음(폴더)
@immutable
sealed class LibraryEntry {
  const LibraryEntry();
}

class LibraryRoutineEntry extends LibraryEntry {
  const LibraryRoutineEntry(this.routine);

  final Routine routine;
}

class LibraryGroupEntry extends LibraryEntry {
  const LibraryGroupEntry(this.group, this.routines);

  final RoutineGroup group;

  /// 묶음 순서대로 정렬한 안의 원본 (일과관리에서 빠진 것은 없다)
  final List<Routine> routines;
}

/// 원본 목록 + 묶음 목록 > 격자 칸: 묶음 먼저(묶음 순서), 그다음 묶음 밖 원본(최신순)
///
/// 묶음 안 원본은 낱개 칸으로 다시 나오지 않는다 — 일과 하나는 한 곳에만 있다.
/// 안의 원본이 2개 미만으로 보이는 묶음(다른 기기에서 지운 직후 등)은 낱개로 펼쳐 보여 준다.
List<LibraryEntry> composeLibraryEntries(
  List<Routine> routines,
  List<RoutineGroup> groups,
) {
  final byId = {for (final routine in routines) routine.id: routine};
  final grouped = <String>{};
  final entries = <LibraryEntry>[];
  final sortedGroups = [...groups]
    ..sort((a, b) => a.displayOrder.compareTo(b.displayOrder));
  for (final group in sortedGroups) {
    final members = [for (final id in group.routineIds) ?byId[id]];
    if (members.length < RoutineGroup.minimumRoutineCount) continue;
    grouped.addAll(members.map((routine) => routine.id));
    entries.add(LibraryGroupEntry(group, members));
  }
  for (final routine in routines) {
    if (!grouped.contains(routine.id)) {
      entries.add(LibraryRoutineEntry(routine));
    }
  }
  return entries;
}

/// 격자 칸 목록. 원본 목록이 실패하면 실패, 묶음 목록만 실패하면 실패로 본다 (반쪽 격자를 보이지 않는다)
final libraryEntriesProvider = Provider<AsyncValue<List<LibraryEntry>>>((ref) {
  final routines = ref.watch(routineLibraryProvider);
  final groups = ref.watch(routineGroupsProvider);
  if (routines case AsyncError(:final error, :final stackTrace)) {
    return AsyncValue.error(error, stackTrace);
  }
  if (groups case AsyncError(:final error, :final stackTrace)) {
    return AsyncValue.error(error, stackTrace);
  }
  final routineList = routines.value;
  final groupList = groups.value;
  if (routineList == null || groupList == null) {
    return const AsyncValue.loading();
  }
  return AsyncValue.data(composeLibraryEntries(routineList, groupList));
});
