import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/logger/app_logger.dart';
import '../../../core/storage/local_storage.dart';
import 'routine_providers.dart';

final firstSendCelebrationProvider = Provider<FirstSendCelebration>(FirstSendCelebration.new);

/// 첫 일과 보내기 축하 판정: 큰 축하는 계정에서 한 번, 그 뒤 보내기는 가벼운 알림
/// 판정 근거 2개: 저장 기록 (이미 축하함) · 오늘 · 지난 목록 (예시 아닌 보낸 일과가 이미 있음)
class FirstSendCelebration {
  FirstSendCelebration(this._ref);

  final Ref _ref;

  LocalStorage get _storage => _ref.read(localStorageProvider);

  /// 보내기 **전에** 부름: 이번이 첫 보내기인가 (보낸 뒤에는 목록에 새 일과가 섞여 판정이 틀어짐)
  /// 목록을 아직 못 받았으면 기록만 봄 (기록이 있어 한 번 넘게 축하하지 않음)
  bool isFirstSendBeforeSending() {
    if (_storage.hasCelebratedFirstSend) return false;
    final todayRoutines = _ref.read(todayRoutinesProvider).value ?? const [];
    final pastRoutines = _ref.read(pastRoutinesProvider).value ?? const [];
    return ![...todayRoutines, ...pastRoutines].any((routine) => !routine.isExample && routine.isVisibleToChild);
  }

  /// 보내기 성공 뒤 기록: 다음부터 큰 축하 없음 (첫 보내기가 아니어도 기록해 다음 판정을 건너뜀)
  Future<void> markSent() async {
    if (_storage.hasCelebratedFirstSend) return;
    try {
      await _storage.setHasCelebratedFirstSend(true);
    } catch (e, stack) {
      // 기록 실패는 다음 보내기에서 한 번 더 축하할 뿐이라 흐름을 막지 않음
      AppLogger.error('firstSend', e, stack, {'step': 'mark'});
    }
  }
}
