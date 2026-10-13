import 'package:dio/dio.dart';
import 'package:elum/core/storage/in_memory_storage.dart';
import 'package:elum/core/storage/token_store.dart';
import 'package:elum/features/auth/data/auth_repository.dart';
import 'package:elum/features/auth/data/oauth_sdk.dart';
import 'package:flutter_test/flutter_test.dart';

/// 결함: 암호 만들기를 건너뛰고 앱을 다시 켜면 잠금 없이 보호자 홈이 열린다.
/// 앱 시작 때 대기 표시를 되살리는 판단만 겨눈다.
void main() {
  AuthRepository repo(InMemoryStorage storage, {bool session = true}) =>
      AuthRepository(
        dio: Dio(),
        storage: storage,
        tokens: InMemoryTokenStore(
          accessToken: session ? 'a' : null,
          refreshToken: session ? 'r' : null,
        ),
        sdk: OAuthSdk(),
      );

  test('세션이 있고 잠금이 없는 보호자 휴대폰은 암호 만들기가 다시 선다', () {
    final r = repo(InMemoryStorage(onboardingCompleted: true))
      ..restoreGuardianPinRequirement(lockMissing: true);
    expect(r.guardianPinSetupPending, isTrue);
    // 화면이 일회 허가를 받아야 로그인으로 튕기지 않는다
    expect(r.consumeGuardianPinSetupPermit(), isTrue);
  });

  test('잠금이 있으면 건드리지 않는다', () {
    final r = repo(InMemoryStorage(onboardingCompleted: true))
      ..restoreGuardianPinRequirement(lockMissing: false);
    expect(r.guardianPinSetupPending, isFalse);
  });

  test('이룸이 휴대폰·세션 없음·온보딩 전은 대상이 아니다', () {
    expect(
      (repo(InMemoryStorage(onboardingCompleted: true, elumiDevice: true))
            ..restoreGuardianPinRequirement(lockMissing: true))
          .guardianPinSetupPending,
      isFalse,
    );
    expect(
      (repo(InMemoryStorage(onboardingCompleted: true), session: false)
            ..restoreGuardianPinRequirement(lockMissing: true))
          .guardianPinSetupPending,
      isFalse,
    );
    expect(
      (repo(InMemoryStorage())..restoreGuardianPinRequirement(lockMissing: true))
          .guardianPinSetupPending,
      isFalse,
    );
  });
}
