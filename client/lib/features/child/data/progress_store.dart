import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/storage/local_storage.dart';
import '../../onboarding/application/onboarding_notifier.dart';
import '../domain/routine_progress_record.dart';

/// 아동 카드 진행 기록의 저장소 래퍼 (이슈 #140).
///
/// [LocalStorage]는 JSON 문자열만 다루므로 직렬화·역직렬화를 여기서 한다.
/// notifier가 저장 형식을 몰라야 저장 방식을 바꿔도 화면 로직이 안 흔들린다.
class ProgressStore {
  ProgressStore(this._storage);

  final LocalStorage _storage;

  /// 저장된 기록. 없거나 깨져 있으면 null — 화면은 서버 값으로 폴백한다.
  RoutineProgressRecord? load(String routineId) {
    final json = _storage.getRoutineProgressJson(routineId);
    if (json == null) return null;
    try {
      final decoded = jsonDecode(json);
      if (decoded is! Map<String, dynamic>) return null;
      return RoutineProgressRecord.fromJson(decoded);
    } catch (_) {
      // 깨진 기록 한 건 때문에 아이 화면이 죽으면 안 된다 (docs 원칙 6번)
      return null;
    }
  }

  Future<void> save(String routineId, RoutineProgressRecord record) =>
      _storage.setRoutineProgressJson(routineId, jsonEncode(record.toJson()));

  Future<void> remove(String routineId) =>
      _storage.removeRoutineProgress(routineId);

  /// 서버 반영이 안 끝난 일과 id.
  Set<String> get pending => _storage.pendingSyncRoutineIds.toSet();

  Future<void> setPending(Set<String> ids) =>
      _storage.setPendingSyncRoutineIds(ids.toList());
}

final progressStoreProvider = Provider<ProgressStore>(
  (ref) => ProgressStore(ref.watch(localStorageProvider)),
);
