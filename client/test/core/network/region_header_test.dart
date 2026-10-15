import 'package:dio/dio.dart';
import 'package:elum/core/network/accept_language_interceptor.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/fake_dio.dart';

/// `X-Elum-Region` 은 `Accept-Language` 와 함께 나가되, 지역이 없거나 비정상이면 **헤더만 빠지고**
/// 요청은 정상으로 나간다. 지역 코드를 돌려주는 함수를 주입해 값을 고정한다.
void main() {
  late FakeAdapter adapter;
  String? region;

  Dio build() {
    adapter = FakeAdapter({'GET /api/ping': {'ok': true}});
    return Dio(BaseOptions(baseUrl: 'https://test.local'))
      ..httpClientAdapter = adapter
      ..interceptors.add(
        AcceptLanguageInterceptor(
          locale: () => const Locale('ko'),
          region: () => region,
        ),
      );
  }

  Future<Map<String, dynamic>> send() async {
    final res = await build().get<dynamic>('/api/ping');
    expect(res.statusCode, 200, reason: '지역 헤더가 없어도 요청은 성공해야 한다');
    return adapter.sentHeaders['GET /api/ping']!;
  }

  bool hasRegion(Map<String, dynamic> h) =>
      h.keys.any((k) => k.toLowerCase() == 'x-elum-region');

  setUp(() => region = null);


  test('KR 을 싣는다', () async {
    region = 'KR';
    expect((await send())['X-Elum-Region'], 'KR');
  });



  test('요청마다 지금 지역을 읽는다 — 값이 아니라 함수를 받는다', () async {
    final dio = build();
    region = 'US';
    await dio.get<dynamic>('/api/ping');
    region = null;
    await dio.get<dynamic>('/api/ping');
    expect(hasRegion(adapter.sentHeaders['GET /api/ping']!), isFalse);
  });


}
