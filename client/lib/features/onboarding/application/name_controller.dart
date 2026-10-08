import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/storage/local_storage.dart';

final nameControllerProvider =
    Provider<NameController>((ref) => NameController(ref));

/// 이룸이 이름 화면이 쓰는 저장소 호출을 모았다.
class NameController {
  NameController(this._ref);

  final Ref _ref;

  /// 고른 역할을 지운다.
  Future<void> clearSelectedRole() => _ref.read(localStorageProvider).clearSelectedRole();
}
