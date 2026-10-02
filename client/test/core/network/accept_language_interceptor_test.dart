import 'package:dio/dio.dart';
import 'package:elum/core/l10n/app_locales.dart';
import 'package:elum/core/network/accept_language_interceptor.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/fake_dio.dart';

/// 요청마다 앱 언어를 `Accept-Language` 로 싣는다 (마스터 C1). 서버가 이것으로 문구 언어를 고른다.
void main() {
  late FakeAdapter adapter;
  var phone = const Locale('ko');

  Dio build({Map<String, Object?>? routes}) {
    adapter = FakeAdapter(routes ?? {'GET /api/ping': {'ok': true}});
    return Dio(BaseOptions(baseUrl: 'https://test.local'))
      ..httpClientAdapter = adapter
      ..interceptors.add(AcceptLanguageInterceptor(locale: () => phone));
  }

  setUp(() => phone = const Locale('ko'));

  group('전송 값 형식 (C1)', () {
    test('ko en ja es 는 언어 코드 그대로, 중국어는 zh-Hans', () {
      expect(AcceptLanguageInterceptor.headerValue(const Locale('ko')), 'ko');
      expect(AcceptLanguageInterceptor.headerValue(const Locale('en')), 'en');
      expect(AcceptLanguageInterceptor.headerValue(const Locale('ja')), 'ja');
      expect(AcceptLanguageInterceptor.headerValue(const Locale('es')), 'es');
      expect(AcceptLanguageInterceptor.headerValue(supportedAppLocales[3]), 'zh-Hans');
    });
  });

  group('요청에 싣기', () {
    test('요청마다 지금 앱 언어를 싣는다', () async {
      final dio = build();
      await dio.get<dynamic>('/api/ping');
      expect(adapter.sentHeaders['GET /api/ping']!['Accept-Language'], 'ko');
    });

    test('앱 언어가 바뀌면 다음 요청부터 따라간다 — 값이 아니라 함수를 받는다', () async {
      final dio = build();
      await dio.get<dynamic>('/api/ping');
      phone = supportedAppLocales[3];
      await dio.get<dynamic>('/api/ping');
      expect(adapter.sentHeaders['GET /api/ping']!['Accept-Language'], 'zh-Hans');
    });

    test('호출부가 직접 정한 값은 덮지 않는다', () async {
      final dio = build();
      await dio.get<dynamic>(
        '/api/ping',
        options: Options(headers: {'accept-language': 'en'}),
      );
      final sent = adapter.sentHeaders['GET /api/ping']!;
      expect(sent['accept-language'] ?? sent['Accept-Language'], 'en');
      expect(
        sent.keys.where((k) => k.toLowerCase() == 'accept-language'),
        hasLength(1),
        reason: '대소문자만 다른 헤더가 두 개 나가면 안 된다',
      );
    });
  });
}
