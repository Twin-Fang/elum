import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:elum/core/network/dio_client.dart';

/// 위젯 테스트가 실제 네트워크를 타지 않게 막는다.
///
/// **왜 필요해졌나.** 예전에는 mock 모드가 켜져 있어 repository가 서버를 아예
/// 부르지 않았고, 그 덕에 테스트도 조용히 지나갔다. mock을 걷어내자(#263) 화면
/// 테스트가 실제로 요청을 보내기 시작했다 — **mock 플래그가 테스트의 네트워크
/// 차단기 노릇을 하고 있었던 것이다.**
///
/// 차단은 테스트가 명시적으로 해야 한다. 그래야 "이 테스트는 서버에서 무엇이
/// 온다고 가정하는가"가 테스트 안에 드러난다.
///
/// [routes]에 `'POST /api/routines'`처럼 `메서드 경로`를 키로 주면 그 응답을
/// 돌려준다. 등록하지 않은 경로는 404를 준다 — 조용히 200을 주면 테스트가
/// 가짜 성공 위에서 돌게 된다.
class FakeAdapter implements HttpClientAdapter {
  FakeAdapter(this.routes);

  final Map<String, Object?> routes;

  /// 실제로 나간 요청. "무엇을 불렀는가"를 검증할 때 쓴다.
  final List<String> calls = [];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    final key = '${options.method} ${options.path}';
    calls.add(key);

    final body = routes[key];
    if (body == null) {
      // 등록하지 않은 경로는 실패로 둔다. 테스트가 기대하지 않은 호출을
      // 성공으로 받으면 그 호출이 일어났다는 사실 자체가 묻힌다.
      throw DioException(
        requestOptions: options,
        response: Response<dynamic>(requestOptions: options, statusCode: 404),
        type: DioExceptionType.badResponse,
      );
    }

    return ResponseBody.fromString(
      jsonEncode(body),
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

/// 테스트용 Dio를 provider에 끼운다.
///
/// riverpod 3.x가 `Override` 타입을 export하지 않아 반환 타입은 추론에 맡긴다
/// (`test_storage.dart`와 같은 사정).
// ignore: strict_top_level_inference
fakeDioOverride(Map<String, Object?> routes) {
  final dio = Dio(BaseOptions(baseUrl: 'https://test.local'))
    ..httpClientAdapter = FakeAdapter(routes);
  return dioProvider.overrideWithValue(dio);
}

/// 어떤 요청도 성공시키지 않는 Dio.
///
/// 네트워크를 쓰지 않는 화면을 검증할 때 쓴다 — 요청이 나가면 실패하므로,
/// 화면이 몰래 서버를 부르고 있었다면 그것이 드러난다.
// ignore: strict_top_level_inference
offlineDioOverride() => fakeDioOverride(const {});
