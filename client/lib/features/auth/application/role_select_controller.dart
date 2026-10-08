import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/storage/local_storage.dart';

final roleSelectControllerProvider =
    Provider<RoleSelectController>((ref) => RoleSelectController(ref));

/// 역할 선택 화면이 쓰는 저장소 호출을 모았다.
class RoleSelectController {
  RoleSelectController(this._ref);

  final Ref _ref;

  Future<void> selectRole(String storageValue) =>
      _ref.read(localStorageProvider).setSelectedRole(storageValue);
}
