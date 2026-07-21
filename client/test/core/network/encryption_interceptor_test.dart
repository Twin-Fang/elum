import 'package:dio/dio.dart';
import 'package:elum/core/network/encryption_interceptor.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const secret = 'test-master-secret-32bytes-minimum!!';

  // 암호화 인터셉터 뒤에 관찰용 인터셉터를 달아, 최종 RequestOptions를 캡처하고 실제 전송은 막는다.
  Future<RequestOptions> capture(Dio dio, Future<void> Function() call) async {
    late RequestOptions captured;
    dio.interceptors.add(InterceptorsWrapper(onRequest: (o, h) {
      captured = o;
      h.reject(DioException(requestOptions: o)); // 실제 전송 차단, 관찰만
    }));
    try {
      await call();
    } catch (_) {}
    return captured;
  }

  test('대상 경로 요청은 봉투로 치환되고 헤더가 붙는다', () async {
    final dio = Dio(BaseOptions(baseUrl: 'https://x'));
    dio.interceptors.add(EncryptionInterceptor(secret: secret));

    final captured = await capture(dio, () => dio.post('/api/routines', data: {'rawInputText': '홍길동'}));

    expect(captured.data, isA<Map>());
    expect((captured.data as Map).containsKey('encrypted'), isTrue);
    expect(captured.headers['X-Elum-Timestamp'], isNotNull);
    expect(captured.headers['X-Elum-Nonce'], isNotNull);
    expect(captured.headers['X-Elum-Signature'], isNotNull);
  });

  test('대상이 아닌 경로는 그대로 통과한다', () async {
    final dio = Dio(BaseOptions(baseUrl: 'https://x'));
    dio.interceptors.add(EncryptionInterceptor(secret: secret));

    final captured = await capture(dio, () => dio.get('/api/member/me'));

    expect(captured.headers.containsKey('X-Elum-Signature'), isFalse);
  });

  test('secret이 비면 대상 경로도 그대로 통과한다', () async {
    final dio = Dio(BaseOptions(baseUrl: 'https://x'));
    dio.interceptors.add(EncryptionInterceptor(secret: ''));

    final captured = await capture(dio, () => dio.post('/api/routines', data: {'rawInputText': '홍길동'}));

    expect((captured.data as Map).containsKey('encrypted'), isFalse);
  });
}
