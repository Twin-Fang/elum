import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/models/routine.dart';
import '../domain/routine_group.dart';
import 'routine_providers.dart';

/// 격자 칸의 종류 (서버 순서 저장 요청의 `type`)
enum LibraryCellType {
  routine('ROUTINE'),
  group('GROUP');

  const LibraryCellType(this.wire);

  final String wire;
}

/// 일과관리 격자 한 칸: 낱개 원본 또는 묶음(폴더)
@immutable
sealed class LibraryEntry {
  const LibraryEntry();

  LibraryCellType get cellType;
  String get id;

  /// 서버에 저장된 자리. 정한 적 없으면 null (#844)
  int? get order;
}

class LibraryRoutineEntry extends LibraryEntry {
  const LibraryRoutineEntry(this.routine);

  final Routine routine;

  @override
  LibraryCellType get cellType => LibraryCellType.routine;

  @override
  String get id => routine.id;

  @override
  int? get order => routine.libraryOrder;
}

class LibraryGroupEntry extends LibraryEntry {
  const LibraryGroupEntry(this.group, this.routines);

  final RoutineGroup group;

  /// 묶음 순서대로 정렬한 안의 원본 (일과관리에서 빠진 것은 없다)
  final List<Routine> routines;

  @override
  LibraryCellType get cellType => LibraryCellType.group;

  @override
  String get id => group.id;

  @override
  int? get order => group.displayOrder;
}

/// 원본 목록 + 묶음 목록 > 격자 칸: 서버에 저장된 자리 순서(묶음·일과 한 줄), 자리가 없는 칸은 그 뒤
///
/// 자리가 같거나 없으면 묶음 먼저, 그다음 서버가 준 원본 순서(최신순).
/// 묶음 안 원본은 낱개 칸으로 다시 나오지 않는다 — 일과 하나는 한 곳에만 있다.
/// 안의 원본이 2개 미만으로 보이는 묶음(다른 기기에서 지운 직후 등)은 낱개로 펼쳐 보여 준다.
List<LibraryEntry> composeLibraryEntries(
  List<Routine> routines,
  List<RoutineGroup> groups,
) {
  final byId = {for (final routine in routines) routine.id: routine};
  final grouped = <String>{};
  final groupEntries = <LibraryEntry>[];
  for (final group in groups) {
    final members = [for (final id in group.routineIds) ?byId[id]];
    if (members.length < RoutineGroup.minimumRoutineCount) continue;
    grouped.addAll(members.map((routine) => routine.id));
    groupEntries.add(LibraryGroupEntry(group, members));
  }
  final looseEntries = <LibraryEntry>[
    for (final routine in routines)
      if (!grouped.contains(routine.id)) LibraryRoutineEntry(routine),
  ];
  // 안정 정렬: 같은 자리면 (묶음 먼저, 서버 순서) 그대로
  final entries = [...groupEntries, ...looseEntries];
  final positionOf = {
    for (final (index, entry) in entries.indexed) entry: index,
  };
  entries.sort((first, second) {
    final byOrder = (first.order ?? _unorderedLast).compareTo(
      second.order ?? _unorderedLast,
    );
    return byOrder != 0
        ? byOrder
        : positionOf[first]!.compareTo(positionOf[second]!);
  });
  return entries;
}

/// 자리를 정한 적 없는 칸은 정한 칸 뒤로 보내는 큰 값
const _unorderedLast = 1 << 30;

/// 칸 하나를 다른 칸 앞/뒤로 옮긴 전체 순서 (서버 순서 저장 요청 본문)
///
/// [movedId] 가 [targetId] 의 앞([isBefore])이나 뒤에 놓인다. 없는 id 면 순서를 그대로 돌려준다.
List<({LibraryCellType type, String id})> reorderCells(
  List<LibraryEntry> entries, {
  required String movedId,
  required String targetId,
  required bool isBefore,
}) {
  final moved = entries.where((entry) => entry.id == movedId).firstOrNull;
  final others = [
    for (final entry in entries)
      if (entry.id != movedId) entry,
  ];
  final targetIndex = others.indexWhere((entry) => entry.id == targetId);
  final result = [...others];
  if (moved != null && targetIndex >= 0) {
    result.insert(isBefore ? targetIndex : targetIndex + 1, moved);
  } else if (moved != null) {
    result.add(moved);
  }
  return [for (final entry in result) (type: entry.cellType, id: entry.id)];
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
