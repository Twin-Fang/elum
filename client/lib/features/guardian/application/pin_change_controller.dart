import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/storage/local_storage.dart';

final pinChangeControllerProvider =
    Provider<PinChangeController>((ref) => PinChangeController(ref));

/// 암호 변경·만들기 화면이 쓰는 저장소 호출을 모았다. 세션 쪽 호출은 AuthSessionController 로 간다.
class PinChangeController {
  PinChangeController(this._ref);

  final Ref _ref;

  Future<bool> hasPin() => _ref.read(localStorageProvider).hasPin();

  Future<bool> verifyPin(String pin) => _ref.read(localStorageProvider).verifyPin(pin);

  Future<void> setPin(String pin) => _ref.read(localStorageProvider).setPin(pin);
}
