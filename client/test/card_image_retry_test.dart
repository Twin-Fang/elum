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

  /// 재시도가 없음을 보일 때: 일어나지 않을 일이라 일정 시간만 기다린다
  Future<void> settle() => Future<void>.delayed(const Duration(milliseconds: 200));

  /// 재시도가 일어날 때: 바쁜 CI 에서도 타이머가 늦지 않도록 조건이 될 때까지 기다린다
  Future<void> waitUntil(bool Function() isDone) async {
    final deadline = DateTime.now().add(const Duration(seconds: 5));
    while (!isDone() && DateTime.now().isBefore(deadline)) {
      await Future<void>.delayed(const Duration(milliseconds: 10));
    }
  }

  test('502 가 두 번 나도 서버가 돌아오면 그림을 받는다', () async {
    final (container, adapter) = setup([502, 502, 200]);

    await waitUntil(() => container.read(cardImageProvider(key)).value != null);

    expect(adapter.calls, 3, reason: '실패 둘 + 성공 하나');
    final bytes = container.read(cardImageProvider(key)).value;
    expect(bytes, isNotNull, reason: '기본 그림에 갇히지 않고 받은 그림으로 바뀐다');
    expect(bytes, Uint8List.fromList([1, 2, 3]));
  });

  test('그림이 없다는 404 는 다시 받지 않는다', () async {
    final (_, adapter) = setup([404]);

    await settle();

    expect(adapter.calls, 1, reason: '다시 해도 같은 실패라 두드리지 않는다');
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
