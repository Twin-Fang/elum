import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:elum/core/logger/app_log_buffer.dart';
import 'package:elum/core/network/app_log_interceptor.dart';
import 'package:flutter_test/flutter_test.dart';

/// 요청·응답·실패 기록과 비밀 값 가리기, 본문 절단, 요청 id 를 고정한다.
void main() {
  setUp(AppLogBuffer.resetForTest);
  tearDown(AppLogBuffer.resetForTest);

  late _Adapter adapter;

  Dio build() {
    adapter = _Adapter();
    return Dio(BaseOptions(baseUrl: 'https://test.local'))
      ..interceptors.add(AppLogInterceptor())
      ..httpClientAdapter = adapter;
  }

  test('요청과 응답을 같은 id 로 남기고 X-Request-Id 헤더로 보낸다', () async {
    final dio = build();
    adapter.reply = _Reply(200, '{"ok":true}');

    await dio.get<dynamic>('/api/a', queryParameters: {'q': '1'});

    final sent = adapter.lastHeaders['X-Request-Id'] as String;
    expect(sent, matches(RegExp(r'^[0-9a-f]{16}$')));
    final text = AppLogBuffer.asText();
    expect(text, contains('→ [$sent] GET /api/a?q=1'));
    expect(text, contains('← [$sent] 200 GET /api/a'));
    expect(text, contains('{"ok":true}'));
  });

  test('Authorization 은 기록하지 않고 선택 헤더만 남긴다', () async {
    final dio = build();
    adapter.reply = _Reply(200, '{}');

    await dio.get<dynamic>(
      '/api/a',
      options: Options(headers: {
        'Authorization': 'Bearer SECRET-VALUE',
        'Accept-Language': 'ko',
        'X-Profile-Id': '7',
      }),
    );

    final text = AppLogBuffer.asText();
    expect(text, isNot(contains('SECRET-VALUE')));
    expect(text.toLowerCase(), isNot(contains('authorization')));
    expect(text, contains('accept-language: ko'));
    expect(text, contains('x-profile-id: 7'));
  });

  test('토큰·암호·PIN 키의 값은 중첩까지 가린다', () async {
    final dio = build();
    adapter.reply = _Reply(
      200,
      jsonEncode({
        'accessToken': 'AT-1',
        'user': {'nickname': '하늘', 'refreshToken': 'RT-1'},
        'list': [
          {'password': 'PW-1', 'ok': 1},
        ],
      }),
    );

    await dio.post<dynamic>('/api/login', data: {
      'pin': '1234',
      'guardianPin': '5678',
      'idToken': 'IDT',
      'code': 'OAUTHCODE',
      'authorization': 'AZ',
      'secret': 'SC',
      'token': 'TK',
      'nested': {'PASSWORD': 'PW-2'},
      'nickname': '하늘',
    });

    final text = AppLogBuffer.asText();
    for (final leaked in [
      'AT-1', 'RT-1', 'PW-1', '1234', '5678', 'IDT', 'OAUTHCODE', 'AZ', 'SC', 'TK', 'PW-2',
    ]) {
      expect(text, isNot(contains(leaked)), reason: leaked);
    }
    expect(text, contains('"accessToken":"****"'));
    expect(text, contains('"nickname":"하늘"'));
  });

  test('의견 전송 본문은 기록에 다시 쌓지 않는다', () async {
    final dio = build();
    adapter.reply = _Reply(200, '{"id":"f1"}');

    await dio.post<dynamic>('/api/feedback', data: {'message': '비밀 의견', 'appLog': '이전 기록'});

    final text = AppLogBuffer.asText();
    expect(text, contains('POST /api/feedback'));
    expect(text, contains('(feedback body omitted)'));
    expect(text, isNot(contains('비밀 의견')));
    expect(text, isNot(contains('이전 기록')));
    expect(text, contains('{"id":"f1"}'));
  });

  test('errorCode 같은 이름은 code 가 아니므로 가리지 않는다', () async {
    final dio = build();
    adapter.reply = _Reply(400, '{"errorCode":"BAD_THING","errorMessage":"x"}');

    await expectLater(dio.get<dynamic>('/api/a'), throwsA(isA<DioException>()));

    final text = AppLogBuffer.asText();
    expect(text, contains('✕ ['));
    expect(text, contains('status=400'));
    expect(text, contains('serverErrorCode=BAD_THING'));
    expect(text, contains('type=badResponse'));
    expect(text, contains('BAD_THING'));
  });

  test('본문은 8000자에서 자르고 생략 글자 수를 적는다', () async {
    final dio = build();
    adapter.reply = _Reply(200, 'a' * 9000);

    // JSON 이 아닌 본문이라 변환기가 먼저 실패하지 않게 문자열 그대로 받는다.
    await dio.get<String>('/api/a', options: Options(responseType: ResponseType.plain));

    final text = AppLogBuffer.asText();
    expect(text, contains('${'a' * 8000}…(1000자 생략)'));
    expect(text, isNot(contains('a' * 8001)));
  });

  test('바이너리·multipart·이미지는 본문을 적지 않는다', () {
    expect(
      AppLogInterceptor.describeBody(Uint8List.fromList(List.filled(300, 65)), null),
      '바이트 300개',
    );
    expect(AppLogInterceptor.describeBody(FormData(), null), '[multipart]');
    expect(AppLogInterceptor.describeBody('xx', 'image/png'), '[이미지 생략]');
    expect(AppLogInterceptor.describeBody(null, null), isNull);
  });

  test('JSON 이 아닌 문자열은 그대로 남긴다', () {
    expect(AppLogInterceptor.describeBody('<html>502</html>', 'text/html'), '<html>502</html>');
  });
}

class _Reply {
  _Reply(this.status, this.body);
  final int status;
  final String body;
}

class _Adapter implements HttpClientAdapter {
  _Reply reply = _Reply(200, '{}');
  Map<String, dynamic> lastHeaders = {};

  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    lastHeaders = Map<String, dynamic>.of(options.headers);
    return ResponseBody.fromString(
      reply.body,
      reply.status,
      headers: {
        Headers.contentTypeHeader: ['application/json'],
      },
    );
  }
}
