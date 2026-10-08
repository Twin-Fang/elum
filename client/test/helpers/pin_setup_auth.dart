import 'package:dio/dio.dart';
import 'package:elum/core/storage/token_store.dart';
import 'package:elum/features/auth/data/auth_repository.dart';
import 'package:elum/features/auth/data/oauth_sdk.dart';
import 'package:elum/core/storage/in_memory_storage.dart';

/// 화면 테스트는 보호자 인증 성공 직후의 일회 허가만 대체한다.
class PinSetupAuth extends AuthRepository {
  PinSetupAuth({required bool allowed}) : _allowed = allowed,
    super(dio: Dio(), storage: InMemoryStorage(), tokens: InMemoryTokenStore(), sdk: OAuthSdk());
  bool _allowed;
  @override
  bool consumeGuardianPinSetupPermit() {
    final allowed = _allowed;
    _allowed = false;
    return allowed;
  }
}
