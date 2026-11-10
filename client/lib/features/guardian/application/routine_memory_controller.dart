import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/logger/app_logger.dart';
import '../../profile/application/profile_session.dart';
import '../data/routine_memory_repository.dart';
import '../domain/routine_memory.dart';

final routineMemoryControllerProvider =
    AsyncNotifierProvider.autoDispose<RoutineMemoryController, RoutineMemory>(
  RoutineMemoryController.new,
);

/// AI 메모리 화면 상태: 불러오기 / 규칙 켜기·끄기·적용·삭제·직접 적기·고치기 / 자동 찾기 스위치 / 모두 지우기 / 내보내기
///
/// 고른 이룸이가 바뀌면 다시 받는다. 저장은 서버에 보낸 뒤 목록을 다시 받아 확정값으로 바꾸고,
/// 실패하면 화면 값을 그대로 두고 오류를 돌려준다 (성공은 null)
class RoutineMemoryController extends AsyncNotifier<RoutineMemory> {
  RoutineMemoryRepository get _repository => ref.read(routineMemoryRepositoryProvider);

  @override
  Future<RoutineMemory> build() {
    ref.watch(profileSessionProvider.select((session) => session.selectedId));
    return _repository.fetch();
  }

  Future<void> reload() async {
    state = const AsyncLoading();
    final refreshed = await AsyncValue.guard(build);
    if (!ref.mounted) return;
    state = refreshed;
  }

  Future<Object?> setEnabled(bool isEnabled) => _save('setEnabled', () => _repository.setEnabled(isEnabled));

  Future<Object?> setRuleStatus(String ruleId, MemoryRuleStatus status) =>
      _save('setRuleStatus', () => _repository.setRuleStatus(ruleId, status));

  Future<Object?> addRule(String text) {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return Future.value(null);
    return _save('addRule', () => _repository.addRule(trimmed));
  }

  Future<Object?> editRuleText(String ruleId, String text) {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return Future.value(null);
    return _save('editRuleText', () => _repository.editRuleText(ruleId, trimmed));
  }

  Future<Object?> deleteRule(String ruleId) => _save('deleteRule', () => _repository.deleteRule(ruleId));

  Future<Object?> clearAll() => _save('clearAll', _repository.clear);

  Future<Object?> _save(String step, Future<void> Function() request) async {
    try {
      await request();
      final saved = await _repository.fetch();
      if (ref.mounted) state = AsyncData(saved);
      return null;
    } catch (e, st) {
      AppLogger.error('routine memory', e, st, {'step': step});
      return e;
    }
  }
}
