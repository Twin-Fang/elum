import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:elum/features/guardian/data/card_image_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// 서버를 재배포하는 동안 카드 그림이 502 로 실패해도 스스로 다시 받는다 (#500).
///
/// 디자이너 휴대폰에서 카드 3번 그림이 502 로 실패해 기본 그림(픽토그램)에 갇혔다가,
/// 카드를 추가해 화면이 다시 그려지자 AI 그림으로 바뀐 일이 있었다.
void main() {
  const key = (routineId: 'r1', stepId: 's1', imagePath: 'k/a.png');
  const delays = [Duration(milliseconds: 20), Duration(milliseconds: 20)];

  /// [statuses]를 차례로 돌려준다. 다 쓰면 마지막 값을 계속 준다.
  (ProviderContainer, _ScriptedAdapter) setup(List<int> statuses) {
    final adapter = _ScriptedAdapter(statuses);
    final dio = Dio(BaseOptions(baseUrl: 'https://test.local'))
      ..httpClientAdapter = adapter;
    final container = ProviderContainer(
      overrides: [
        cardImageRepositoryProvider.overrideWithValue(
          CardImageRepository(dio: dio, retryDelays: delays),
        ),
      ],
    );
    addTearDown(container.dispose);
    // autoDispose 라 구독해 둬야 재시도가 도는 동안 살아 있다 — 위젯이 보고 있는 상황이다
    container.listen(cardImageProvider(key), (_, _) {});
    return (container, adapter);
  }

  Future<void> settle() => Future<void>.delayed(const Duration(milliseconds: 200));

  test('502 가 두 번 나도 서버가 돌아오면 그림을 받는다', () async {
    final (container, adapter) = setup([502, 502, 200]);

    await settle();

    expect(adapter.calls, 3, reason: '실패 둘 + 성공 하나');
    final bytes = container.read(cardImageProvider(key)).value;
    expect(bytes, isNotNull, reason: '기본 그림에 갇히지 않고 받은 그림으로 바뀐다');
    expect(bytes, Uint8List.fromList([1, 2, 3]));
  });

  test('계속 실패하면 정해진 횟수까지만 다시 받는다', () async {
    final (container, adapter) = setup([502]);

    await settle();
    await settle();

    expect(adapter.calls, 1 + delays.length, reason: '처음 한 번 + 재시도 상한');
    expect(container.read(cardImageProvider(key)).value, isNull);
  });

  test('그림이 없다는 404 는 다시 받지 않는다', () async {
    final (_, adapter) = setup([404]);

    await settle();

    expect(adapter.calls, 1, reason: '다시 해도 같은 실패라 두드리지 않는다');
  });

  test('권한이 없다는 401 도 다시 받지 않는다', () async {
    final (_, adapter) = setup([401]);

    await settle();

    expect(adapter.calls, 1);
  });

  test('일시 오류인지 가린다', () {
    DioException badResponse(int code) => DioException(
          requestOptions: RequestOptions(),
          response: Response(requestOptions: RequestOptions(), statusCode: code),
          type: DioExceptionType.badResponse,
        );
    DioException of(DioExceptionType type) =>
        DioException(requestOptions: RequestOptions(), type: type);

    for (final code in [408, 429, 502, 503, 504]) {
      expect(CardImageRepository.isTransientFailure(badResponse(code)), isTrue, reason: '$code');
    }
    for (final code in [400, 401, 403, 404, 500]) {
      expect(CardImageRepository.isTransientFailure(badResponse(code)), isFalse, reason: '$code');
    }
    for (final type in [
      DioExceptionType.connectionTimeout,
      DioExceptionType.sendTimeout,
      DioExceptionType.receiveTimeout,
      DioExceptionType.connectionError,
    ]) {
      expect(CardImageRepository.isTransientFailure(of(type)), isTrue, reason: '$type');
    }
    expect(CardImageRepository.isTransientFailure(of(DioExceptionType.cancel)), isFalse);
    expect(CardImageRepository.isTransientFailure(StateError('x')), isFalse);
  });
}

class _ScriptedAdapter implements HttpClientAdapter {
  _ScriptedAdapter(this._statuses);

  final List<int> _statuses;
  int calls = 0;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    final status = _statuses[calls < _statuses.length ? calls : _statuses.length - 1];
    calls++;
    if (status >= 400) {
      // 실제 dio 는 4xx/5xx 에 예외를 던진다
      throw DioException(
        requestOptions: options,
        response: Response(requestOptions: options, statusCode: status),
        type: DioExceptionType.badResponse,
      );
    }
    return ResponseBody.fromBytes(
      [1, 2, 3],
      status,
      headers: {
        Headers.contentTypeHeader: ['image/png'],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}
