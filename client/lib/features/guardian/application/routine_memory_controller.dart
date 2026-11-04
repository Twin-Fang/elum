import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/logger/app_logger.dart';
import '../data/routine_memory_repository.dart';
import '../domain/routine_memory.dart';

final routineMemoryControllerProvider =
    AsyncNotifierProvider.autoDispose<RoutineMemoryController, RoutineMemory>(
  RoutineMemoryController.new,
);

/// AI 메모 화면 상태: 불러오기 / 켜기·끄기 / 줄 고치기·더하기·지우기 / 모두 지우기
/// 저장은 서버 확정값으로 바꾸고, 실패하면 화면 값을 그대로 두고 오류를 돌려준다 (성공은 null)
class RoutineMemoryController extends AsyncNotifier<RoutineMemory> {
  RoutineMemoryRepository get _repository => ref.read(routineMemoryRepositoryProvider);

  @override
  Future<RoutineMemory> build() => _repository.fetch();

  Future<void> reload() async {
    state = const AsyncLoading();
    final refreshed = await AsyncValue.guard(build);
    if (!ref.mounted) return;
    state = refreshed;
  }

  Future<Object?> setEnabled(bool isEnabled) =>
      _save('setEnabled', () => _repository.setEnabled(isEnabled));

  /// 줄 하나 고치기 (index 자리), 빈 글이면 지우기
  Future<Object?> replaceLine(int index, String text) {
    final texts = [...?state.value?.lineTexts];
    if (index < 0 || index >= texts.length) return Future.value(null);
    final trimmed = text.trim();
    if (trimmed.isEmpty) {
      texts.removeAt(index);
    } else {
      texts[index] = trimmed;
    }
    return _save('replaceLine', () => _repository.replaceLines(texts));
  }

  Future<Object?> addLine(String text) {
    final trimmed = text.trim();
    final current = state.value;
    if (trimmed.isEmpty || current == null || !current.canAddLine) return Future.value(null);
    return _save('addLine', () => _repository.replaceLines([...current.lineTexts, trimmed]));
  }

  Future<Object?> removeLine(int index) => replaceLine(index, '');

  Future<Object?> clearAll() => _save('clearAll', _repository.clear);

  Future<Object?> _save(String step, Future<RoutineMemory> Function() request) async {
    try {
      final saved = await request();
      if (ref.mounted) state = AsyncData(saved);
      return null;
    } catch (e, st) {
      AppLogger.error('routine memory', e, st, {'step': step});
      return e;
    }
  }
}
