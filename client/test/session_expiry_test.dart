import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:elum/core/network/auth_interceptor.dart';
import 'package:elum/core/storage/token_store.dart';

/// 토큰 갱신까지 실패하면 세션이 끝난 것이다. 그 사실을 알리지 않으면 화면이
/// 로컬 캐시로 계속 그려져, 사용자는 로그인이 풀린 줄 모른 채 쓰게 된다 (이슈 #175).
void main() {
  late InMemoryTokenStore tokens;
  late Dio dio;

  setUp(() {
    tokens = InMemoryTokenStore();
    dio = Dio(BaseOptions(baseUrl: 'https://example.test'));
  });

  DioException unauthorized({bool retried = false}) => DioException(
        requestOptions: RequestOptions(
          path: '/api/member/me',
          extra: retried ? {'authRetried': true} : {},
        ),
        response: Response<dynamic>(
          statusCode: 401,
          requestOptions: RequestOptions(path: '/api/member/me'),
        ),
      );

  /// onError를 부르고 handler가 무엇을 했는지 돌려준다.
  Future<void> fireError(AuthInterceptor sut, DioException err) {
    final completer = _RecordingHandler();
    sut.onError(err, completer);
    return completer.done;
  }

  test('갱신이 실패하면 세션 종료를 알리고 토큰을 지운다', () async {
    var notified = 0;
    await tokens.save(accessToken: 'a', refreshToken: 'r');

    final sut = AuthInterceptor(
      tokens: tokens,
      dio: dio,
      refresh: () async => null, // 갱신 실패
      onSessionExpired: () => notified++,
    );

    await fireError(sut, unauthorized());

    expect(notified, 1, reason: '알리지 않으면 화면이 정상처럼 남는다');
    expect(tokens.accessToken, isNull, reason: '쓸 수 없는 토큰은 남겨두지 않는다');
  });

  test('갱신에 성공하면 세션 종료를 알리지 않는다', () async {
    var notified = 0;
    await tokens.save(accessToken: 'a', refreshToken: 'r');

    final sut = AuthInterceptor(
      tokens: tokens,
      dio: dio,
      refresh: () async => 'new-token',
      onSessionExpired: () => notified++,
    );

    await fireError(sut, unauthorized());

    expect(notified, 0, reason: '갱신되면 세션은 살아 있다');
  });

  test('이미 재시도한 요청이면 갱신을 다시 시도하지 않는다', () async {
    var refreshCalls = 0;
    var notified = 0;

    final sut = AuthInterceptor(
      tokens: tokens,
      dio: dio,
      refresh: () async {
        refreshCalls++;
        return null;
      },
      onSessionExpired: () => notified++,
    );

    await fireError(sut, unauthorized(retried: true));

    expect(refreshCalls, 0, reason: '무한 루프 방지');
    expect(notified, 0);
  });
}

/// handler 호출을 기다릴 수 있게 감싼다.
class _RecordingHandler extends ErrorInterceptorHandler {
  final _completer = Completer<void>();
  Future<void> get done => _completer.future;

  @override
  void next(DioException err) {
    if (!_completer.isCompleted) _completer.complete();
  }

  @override
  void resolve(Response<dynamic> response) {
    if (!_completer.isCompleted) _completer.complete();
  }

  @override
  void reject(DioException error, [bool callFollowingErrorInterceptor = false]) {
    if (!_completer.isCompleted) _completer.complete();
  }
}
