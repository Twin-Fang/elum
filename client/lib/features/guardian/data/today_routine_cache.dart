import 'dart:convert';

import '../../../core/logger/app_logger.dart';
import '../../../core/storage/local_storage.dart';
import '../../../shared/models/routine.dart';

/// 오늘 일과 오프라인 캐시: 저장, 읽기(깨진 캐시는 null), 오늘 것만 거르기
/// storage 가 null 이면 캐시 없이 동작
class TodayRoutineCache {
  TodayRoutineCache(this._storage);

  final LocalStorage? _storage;

  /// 성공한 응답을 저장한다. toJson 이 보호자 원문을 빼고 직렬화한다.
  Future<void> save(List<Routine> routines) async {
    await _storage?.setCachedTodayRoutinesJson(
      jsonEncode(routines.map((r) => r.toJson()).toList()),
    );
  }

  /// 캐시가 깨져 있으면 null — 폴백으로 넘긴다. 캐시 한 건 때문에 화면이 죽으면 안 된다.
  ///
  /// 이전 빌드가 저장한 캐시에는 보호자 원문 키가 남아 있을 수 있다.
  /// 읽을 때 그 키를 지워 다시 쓰므로, 오프라인으로만 열어도 원문이 오래 남지 않는다.
  /// 서버 `/today` 와 같은 규칙으로 거른다 — 어제 받아 둔 캐시나 전체 목록 폴백이
  /// 오늘 일과로 나가지 않게 한다.
  // 서버 /today 와 같은 기준으로 오늘 일과만 남김
  List<Routine> onlyToday(List<Routine> routines) {
    final now = DateTime.now();
    return routines.where((r) => r.isTodayOn(now)).toList();
  }

  List<Routine>? read() {
    final json = _storage?.cachedTodayRoutinesJson;
    if (json == null) return null;
    try {
      final decoded = jsonDecode(json);
      if (decoded is! List) return null;
      final maps = decoded.whereType<Map<String, dynamic>>().toList();
      final routines = maps.map(Routine.fromJson).toList();
      if (maps.any(
        (m) =>
            m.containsKey('rawInputText') ||
            m.containsKey('sanitizedInputText'),
      )) {
        _rewriteCachedWithoutRaw(routines);
      }
      return routines;
    } catch (_) {
      return null;
    }
  }

  /// 원문 키가 빠진 형태로 캐시를 덮어쓴다. 쓰기 실패는 읽기 결과에 영향 주지 않는다.
  void _rewriteCachedWithoutRaw(List<Routine> routines) {
    try {
      _storage
          ?.setCachedTodayRoutinesJson(
            jsonEncode(routines.map((r) => r.toJson()).toList()),
          )
          .catchError((Object e) {
            AppLogger.repositoryError('RoutineRepository', 'cacheMigrate', e);
          });
    } catch (e) {
      AppLogger.repositoryError('RoutineRepository', 'cacheMigrate', e);
    }
  }

  // --- 로컬 대체 구현 ---

  /// 서버 없이도 데모가 성립하도록 로컬에서 일과를 구성한다.
}
