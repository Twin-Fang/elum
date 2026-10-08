import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/app_failure.dart';
import '../data/device_link_repository.dart';

final elumiSettingsControllerProvider =
    Provider<ElumiSettingsController>((ref) => ElumiSettingsController(ref));

/// 이룸이 설정 화면이 쓰는 연결 저장소 호출을 모았다.
class ElumiSettingsController {
  ElumiSettingsController(this._ref);

  final Ref _ref;

  Future<AppFailure?> disconnectThisPhone() =>
      _ref.read(deviceLinkRepositoryProvider).disconnectThisPhone();
}
