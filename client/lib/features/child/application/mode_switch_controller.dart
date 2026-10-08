import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/storage/local_storage.dart';

final modeSwitchControllerProvider =
    Provider<ModeSwitchController>((ref) => ModeSwitchController(ref));

/// 화면 전환 암호 화면이 쓰는 저장소 호출을 모았다.
class ModeSwitchController {
  ModeSwitchController(this._ref);

  final Ref _ref;

  Future<bool> hasPin() => _ref.read(localStorageProvider).hasPin();

  bool get isElumiDevice => _ref.read(localStorageProvider).isElumiDevice;

  Future<bool> verifyPin(String entered) =>
      _ref.read(localStorageProvider).verifyPin(entered);
}
