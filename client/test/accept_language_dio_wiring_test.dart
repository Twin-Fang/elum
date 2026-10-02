import 'package:elum/core/dev/dev_locale_override.dart';
import 'package:elum/core/network/dio_client.dart';
import 'package:elum/core/storage/local_storage.dart';
import 'package:elum/core/storage/token_store.dart';
import 'package:elum/features/auth/data/auth_repository.dart';
import 'package:elum/features/onboarding/application/onboarding_notifier.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/fake_dio.dart';

/// 앱이 실제로 쓰는 Dio(`dioProvider`)에 언어 헤더가 붙어 있는가.
///
/// 인터셉터 단위 테스트가 통과해도 **provider 에 안 달려 있으면** 헤더는 영영 안 나간다.
void main() {
  final binding = TestWidgetsFlutterBinding.ensureInitialized();
  late FakeAdapter adapter;

  ProviderContainer build() {
    final c = ProviderContainer(
      overrides: [
        localStorageProvider.overrideWithValue(InMemoryStorage(onboardingCompleted: true)),
        tokenStoreProvider.overrideWithValue(InMemoryTokenStore()),
      ],
    );
    addTearDown(c.dispose);
    adapter = FakeAdapter({'GET /api/ping': {'ok': true}});
    c.read(dioProvider).httpClientAdapter = adapter;
    return c;
  }

  Future<String?> sentLanguage(ProviderContainer c) async {
    await c.read(dioProvider).get<dynamic>('/api/ping');
    return adapter.sentHeaders['GET /api/ping']!['Accept-Language'] as String?;
  }

  tearDown(() {
    binding.platformDispatcher.clearLocalesTestValue();
    dotenv.loadFromString(envString: '', isOptional: true);
  });

  test('휴대폰 언어가 요청 헤더로 나간다', () async {
    binding.platformDispatcher.localesTestValue = const [Locale('es', 'MX')];
    expect(await sentLanguage(build()), 'es');
  });

  test('중국어 간체는 zh-Hans, 지원 밖 언어는 en', () async {
    binding.platformDispatcher.localesTestValue = const [Locale('zh', 'CN')];
    expect(await sentLanguage(build()), 'zh-Hans');
    binding.platformDispatcher.localesTestValue = const [Locale('fr', 'FR')];
    expect(await sentLanguage(build()), 'en');
  });

  test('개발자 도구가 강제한 언어가 이긴다', () async {
    dotenv.loadFromString(envString: 'ELUM_SHOW_DEV_TOOLS=true');
    binding.platformDispatcher.localesTestValue = const [Locale('ko', 'KR')];
    final c = build();
    c.read(devLocaleOverrideProvider.notifier).set(const Locale('ja'));
    expect(await sentLanguage(c), 'ja');
  });

  test('개발자 도구가 꺼져 있으면 휴대폰 언어를 보낸다', () async {
    dotenv.loadFromString(envString: 'ELUM_SHOW_DEV_TOOLS=false');
    binding.platformDispatcher.localesTestValue = const [Locale('ko', 'KR')];
    final c = build();
    c.read(devLocaleOverrideProvider.notifier).set(const Locale('ja'));
    expect(await sentLanguage(c), 'ko');
  });
}
