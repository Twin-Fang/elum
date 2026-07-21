import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:elum/features/guardian/data/card_image_repository.dart';
import 'package:flutter_test/flutter_test.dart';

/// 카드 이미지 조회 테스트.
///
/// 서버가 인증된 요청에만 이미지를 준다. `Image.network`는 Authorization
/// 헤더를 못 붙여 401을 받으므로 바이트를 직접 받아야 한다.
void main() {
  late _FakeAdapter adapter;
  late CardImageRepository repo;

  setUp(() {
    adapter = _FakeAdapter();
    final dio = Dio(BaseOptions(baseUrl: 'https://test.local'))
      ..httpClientAdapter = adapter;
    repo = CardImageRepository(dio: dio);
  });

  test('이미지 바이트를 그대로 돌려준다', () async {
    adapter.stub(200, [1, 2, 3, 4]);

    final bytes = await repo.fetch(routineId: 'r1', stepId: 's1');

    expect(bytes, isA<Uint8List>());
    expect(bytes, [1, 2, 3, 4]);
  });

  test('올바른 경로로 요청한다', () async {
    adapter.stub(200, [1]);

    await repo.fetch(routineId: 'r1', stepId: 's1');

    expect(adapter.lastPath, '/api/routines/r1/steps/s1/image');
  });

  test('실패하면 null을 준다 — 예외를 던지지 않는다', () async {
    // 이미지 한 장 때문에 카드가 사라지면 안 된다
    adapter.stub(404, []);

    expect(await repo.fetch(routineId: 'r1', stepId: 's1'), isNull);
  });

  test('빈 응답도 null로 처리한다', () async {
    // 0바이트를 Image.memory에 넘기면 터진다
    adapter.stub(200, []);

    expect(await repo.fetch(routineId: 'r1', stepId: 's1'), isNull);
  });

  test('서버가 죽어도 예외가 새어나오지 않는다', () async {
    adapter.stub(502, []);

    expect(
      () => repo.fetch(routineId: 'r1', stepId: 's1'),
      returnsNormally,
    );
    expect(await repo.fetch(routineId: 'r1', stepId: 's1'), isNull);
  });
}

class _FakeAdapter implements HttpClientAdapter {
  int _status = 200;
  List<int> _body = const [];
  String? lastPath;

  void stub(int status, List<int> body) {
    _status = status;
    _body = body;
  }

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    lastPath = options.path;

    if (_status >= 400) {
      // 실제 dio는 4xx/5xx에 예외를 던진다
      throw DioException(
        requestOptions: options,
        response: Response(requestOptions: options, statusCode: _status),
        type: DioExceptionType.badResponse,
      );
    }

    return ResponseBody.fromBytes(
      _body,
      _status,
      headers: {
        Headers.contentTypeHeader: ['image/png'],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}
