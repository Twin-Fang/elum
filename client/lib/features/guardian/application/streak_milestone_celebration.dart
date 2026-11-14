import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/logger/app_logger.dart';
import '../../../core/storage/local_storage.dart';
import '../../member/domain/elumi_streak.dart';

final streakMilestoneCelebrationProvider = Provider<StreakMilestoneCelebration>(StreakMilestoneCelebration.new);

/// 연속 기록 축하 판정 (보호자 홈): 이룸이마다 축하 일수(3 · 7 · 14 · 30)는 한 번만
/// 한꺼번에 여러 일수를 넘었으면 가장 큰 일수 하나만 축하하고 아래 일수도 함께 기록
class StreakMilestoneCelebration {
  StreakMilestoneCelebration(this._ref);

  final Ref _ref;

  LocalStorage get _storage => _ref.read(localStorageProvider);

  /// 지금 축하할 일수 (이미 축하했거나 닿은 일수가 없으면 null)
  int? milestoneToCelebrate({required String? profileId, required ElumiStreak streak}) {
    final milestone = streak.reachedMilestone;
    if (profileId == null || milestone == null) return null;
    final celebratedKeys = _storage.celebratedStreakMilestoneKeys;
    return celebratedKeys.contains(_keyOf(profileId, milestone)) ? null : milestone;
  }

  /// 축하를 띄운 뒤 기록: 이 일수와 그 아래 축하 일수 전부
  Future<void> markCelebrated({required String profileId, required int milestone}) async {
    final celebratedKeys = {
      ..._storage.celebratedStreakMilestoneKeys,
      for (final day in ElumiStreak.milestoneDays.where((day) => day <= milestone)) _keyOf(profileId, day),
    };
    try {
      await _storage.setCelebratedStreakMilestoneKeys(celebratedKeys);
    } catch (e, stack) {
      // 기록 실패는 다음 홈 진입에 한 번 더 축하할 뿐이라 흐름을 막지 않음
      AppLogger.error('streakMilestone', e, stack, {'step': 'mark'});
    }
  }

  /// 저장 키: `{이룸이 id}:{일수}`
  static String _keyOf(String profileId, int milestone) => '$profileId:$milestone';
}
