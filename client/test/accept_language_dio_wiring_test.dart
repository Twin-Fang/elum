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
    binding.platformDispatcher.localesTestValue = const [Locale('en', 'US')];
    expect(await sentLanguage(build()), 'en');
    binding.platformDispatcher.localesTestValue = const [Locale('ko', 'KR')];
    expect(await sentLanguage(build()), 'ko');
  });

  test('열지 않은 스페인어 휴대폰은 en 으로 나간다', () async {
    binding.platformDispatcher.localesTestValue = const [Locale('es', 'MX')];
    expect(await sentLanguage(build()), 'en');
  });

  test('열지 않은 중국어 간체와 지원 밖 언어는 en', () async {
    binding.platformDispatcher.localesTestValue = const [Locale('zh', 'CN')];
    expect(await sentLanguage(build()), 'en');
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

  test('휴대폰 지역이 X-Elum-Region 으로 나간다', () async {
    binding.platformDispatcher.localesTestValue = const [Locale('en', 'US')];
    final c = build();
    await c.read(dioProvider).get<dynamic>('/api/ping');
    expect(adapter.sentHeaders['GET /api/ping']!['X-Elum-Region'], 'US');

    binding.platformDispatcher.localesTestValue = const [Locale('ko', 'KR')];
    await c.read(dioProvider).get<dynamic>('/api/ping');
    expect(adapter.sentHeaders['GET /api/ping']!['X-Elum-Region'], 'KR');
  });

  test('개발자 도구가 언어를 강제해도 지역은 시스템 로케일 값이다', () async {
    dotenv.loadFromString(envString: 'ELUM_SHOW_DEV_TOOLS=true');
    binding.platformDispatcher.localesTestValue = const [Locale('en', 'US')];
    final c = build();
    c.read(devLocaleOverrideProvider.notifier).set(const Locale('ja'));
    await c.read(dioProvider).get<dynamic>('/api/ping');
    final sent = adapter.sentHeaders['GET /api/ping']!;
    expect(sent['Accept-Language'], 'ja', reason: '강제는 언어만 바꾼다');
    expect(sent['X-Elum-Region'], 'US', reason: '지역은 시스템 값 그대로');
  });

  test('휴대폰 지역이 없으면 지역 헤더 없이 나가고 요청은 성공한다', () async {
    binding.platformDispatcher.localesTestValue = const [Locale('ja')];
    final c = build();
    final res = await c.read(dioProvider).get<dynamic>('/api/ping');
    expect(res.statusCode, 200);
    expect(
      adapter.sentHeaders['GET /api/ping']!.keys.map((k) => k.toLowerCase()),
      isNot(contains('x-elum-region')),
    );
  });
}
