import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/app_failure.dart';
import '../data/auth_repository.dart';

final authSessionControllerProvider =
    Provider<AuthSessionController>((ref) => AuthSessionController(ref));

/// 다른 기능의 화면이 인증 저장소를 직접 import 하지 않고 세션 상태·계정 동작을 쓰는 통로.
class AuthSessionController {
  AuthSessionController(this._ref);

  final Ref _ref;

  bool get hasSession => _ref.read(authRepositoryProvider).hasSession;

  Future<void> logout() => _ref.read(authRepositoryProvider).logout();

  Future<AppFailure?> deleteAccount() => _ref.read(authRepositoryProvider).deleteAccount();

  /// 보호자 인증이 남긴 암호 만들기 일회 허가를 소비한다.
  bool consumeGuardianPinSetupPermit() =>
      _ref.read(authRepositoryProvider).consumeGuardianPinSetupPermit();

  /// 암호 만들기 대기를 끈다.
  void finishGuardianPinSetup() =>
      _ref.read(authRepositoryProvider).finishGuardianPinSetup();
}
