import 'package:elum/core/router/app_destination.dart';
import 'package:elum/core/storage/local_storage.dart';
import 'package:elum/core/storage/token_store.dart';
import 'package:elum/features/auth/data/auth_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:elum/core/storage/in_memory_storage.dart';
import 'package:elum/core/router/routes.dart';

/// 지금 상태의 홈 — 앱 시작과 뒤로가기 안전망이 같은 판단을 쓴다.
void main() {
  ProviderContainer containerWith({
    required InMemoryStorage storage,
    required InMemoryTokenStore tokens,
  }) {
    final c = ProviderContainer(
      overrides: [
        localStorageProvider.overrideWithValue(storage),
        tokenStoreProvider.overrideWithValue(tokens),
      ],
    );
    addTearDown(c.dispose);
    return c;
  }

  test('연결된 이룸이 휴대폰은 이룸이 홈이다', () {
    final c = containerWith(
      storage: InMemoryStorage(elumiDevice: true, onboardingCompleted: true),
      tokens: InMemoryTokenStore(accessToken: 'a', refreshToken: 'r'),
    );
    expect(homeFor(c), Routes.child);
  });

}
