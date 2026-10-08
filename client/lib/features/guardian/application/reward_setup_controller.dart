import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/models/routine.dart';
import 'routine_providers.dart';

final rewardSetupControllerProvider =
    Provider<RewardSetupController>((ref) => RewardSetupController(ref));

/// 보상 설정 화면이 쓰는 일과 저장소 호출을 모았다.
class RewardSetupController {
  RewardSetupController(this._ref);

  final Ref _ref;

  Future<List<RecentReward>> recentRewards() =>
      _ref.read(routineRepositoryProvider).getRecentRewards();
}
