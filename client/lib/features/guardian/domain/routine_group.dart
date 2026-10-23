import 'package:flutter/foundation.dart';

/// 일과 묶음(폴더) — 서버 `RoutineGroupResponse` (#806)
///
/// [routineIds] 순서가 곧 이룸이에게 보이는 순서다. 묶음은 늘 일과 1개 이상이다.
@immutable
class RoutineGroup {
  const RoutineGroup({
    required this.id,
    required this.name,
    required this.routineIds,
    this.displayOrder = 0,
  });

  final String id;
  final String name;
  final List<String> routineIds;
  final int displayOrder;

  /// 묶음 이름 글자 수 상한. 서버 검증과 같은 값
  static const nameMaxLength = 12;

  /// 묶음이 이루어지는 최소 일과 수 (다 빠지면 묶음이 풀린다)
  static const minimumRoutineCount = 1;

  /// 응답 모양이 어긋나도 목록이 죽지 않게 읽는다 (id 없으면 null)
  static RoutineGroup? tryFromJson(Object? json) {
    if (json is! Map<String, dynamic>) return null;
    final id = json['id']?.toString() ?? '';
    if (id.isEmpty) return null;
    return RoutineGroup(
      id: id,
      name: json['name']?.toString() ?? '',
      displayOrder: switch (json['displayOrder']) {
        final int order => order,
        _ => 0,
      },
      routineIds: switch (json['routineIds']) {
        final List<dynamic> ids => [
          for (final id in ids)
            if (id != null && id.toString().isNotEmpty) id.toString(),
        ],
        _ => const <String>[],
      },
    );
  }
}
