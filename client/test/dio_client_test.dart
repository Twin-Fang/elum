import 'package:dio/dio.dart';
import 'package:elum/core/network/dio_client.dart';
import 'package:flutter_test/flutter_test.dart';

/// 로깅 인터셉터 회귀 테스트.
///
/// 인터셉터는 Dio 인스턴스당 하나만 생성되어 모든 요청이 공유한다.
/// 요청별 상태를 인스턴스 필드에 담으면 두 번째 요청부터 죽는데,
/// 그 예외가 DioException으로 감싸여 나오기 때문에 "서버 장애"처럼 보인다.
/// 실제로 요청이 네트워크로 나가지도 못한 채 statusCode 0으로 실패했다.
void main() {
  /// 실제 통신 없이 인터셉터 체인만 태운다.
  /// 요청을 그대로 200으로 돌려주는 어댑터.
  Dio buildDio() {
    final dio = Dio(BaseOptions(baseUrl: 'https://example.test'))
      ..interceptors.add(SafeLogInterceptor())
      ..httpClientAdapter = _EchoAdapter();
    return dio;
  }

  group('SafeLogInterceptor', () {
    test('같은 인터셉터로 요청을 연속 두 번 보내도 실패하지 않는다', () async {
      final dio = buildDio();

      // 1회차는 원래도 통과했다. 회귀가 드러나는 지점은 2회차다.
      final first = await dio.post<dynamic>('/api/auth/signup');
      final second = await dio.post<dynamic>('/api/auth/login');

      expect(first.statusCode, 200);
      expect(second.statusCode, 200);
    });

    test('동시 요청을 섞어 보내도 모두 성공한다', () async {
      final dio = buildDio();

      // 요청별 소요시간이 인스턴스 필드에 있으면 여기서 값이 뒤섞인다.
      final responses = await Future.wait([
        dio.post<dynamic>('/api/auth/signup'),
        dio.post<dynamic>('/api/auth/login'),
        dio.get<dynamic>('/api/member/me'),
      ]);

      expect(responses.map((r) => r.statusCode), everyElement(200));
    });

    test('에러 응답이 반복돼도 인터셉터가 죽지 않는다', () async {
      final dio = Dio(BaseOptions(baseUrl: 'https://example.test'))
        ..interceptors.add(SafeLogInterceptor())
        ..httpClientAdapter = _FailingAdapter();

      // 실패 경로도 onRequest를 거친다. 여기서 죽으면 재시도 루프가 무한히 돈다.
      for (var i = 0; i < 3; i++) {
        await expectLater(
          dio.post<dynamic>('/api/auth/login'),
          throwsA(
            isA<DioException>().having(
              (e) => e.response?.statusCode,
              'statusCode',
              // 인터셉터 자체 예외(statusCode 0)가 아니라 서버가 준 500이어야 한다.
              500,
            ),
          ),
        );
      }
    });
  });
}

/// 요청을 그대로 200으로 되돌려주는 어댑터.
class _EchoAdapter implements HttpClientAdapter {
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    return ResponseBody.fromString('{"ok":true}', 200, headers: {
      Headers.contentTypeHeader: [Headers.jsonContentType],
    });
  }

  @override
  void close({bool force = false}) {}
}

/// 항상 500을 돌려주는 어댑터.
class _FailingAdapter implements HttpClientAdapter {
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    return ResponseBody.fromString('{"message":"boom"}', 500, headers: {
      Headers.contentTypeHeader: [Headers.jsonContentType],
    });
  }

  @override
  void close({bool force = false}) {}
}
