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

  // 깨지면: 보호자가 적은 일과 원문이 의견 첨부 기록으로 서버에 올라간다 (docs 원칙 5번)
  test('일과 원문·답·보상 문구는 요청·응답 모두 가린다', () async {
    final dio = build();
    adapter.reply = _Reply(
      200,
      jsonEncode({'rawInputText': 'RAW-RES', 'sanitizedInputText': 'SAN-RES', 'id': 3}),
    );

    await dio.post<dynamic>('/api/routines', data: {
      'rawInputText': 'RAW-REQ',
      'answers': ['ANS-1'],
      'rewardText': 'RWD',
    });

    final text = AppLogBuffer.asText();
    for (final leaked in ['RAW-RES', 'SAN-RES', 'RAW-REQ', 'ANS-1', 'RWD']) {
      expect(text, isNot(contains(leaked)), reason: leaked);
    }
    expect(text, contains('"id":3'));
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
