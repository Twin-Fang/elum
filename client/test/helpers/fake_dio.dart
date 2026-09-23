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
  FakeAdapter(this.routes, {this.delay = Duration.zero});

  final Map<String, Object?> routes;

  /// 응답을 이만큼 늦춘다. 기본은 즉시다.
  ///
  /// 로딩 연출처럼 **응답이 늦을 때의 동작**을 봐야 하는 화면에 쓴다.
  /// 즉시 응답하면 "결과를 기다리는 동안"의 흐름을 아예 지나쳐 버린다.
  final Duration delay;

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

    if (delay > Duration.zero) await Future<void>.delayed(delay);

    final body = routes[key];

    // 서버가 실패를 돌려주는 경우. 성공 본문만 흉내 낼 수 있으면 한도 초과나
    // 계정 정지처럼 **서버가 이유를 알려주는 실패 경로**를 테스트할 수 없다 (#347).
    if (body is FakeHttpError) {
      throw DioException(
        requestOptions: options,
        response: Response<dynamic>(
          requestOptions: options,
          statusCode: body.status,
          data: {
            if (body.errorCode != null) 'errorCode': body.errorCode,
            if (body.errorMessage != null) 'errorMessage': body.errorMessage,
          },
        ),
        type: DioExceptionType.badResponse,
      );
    }

    // 서버에 닿지 못했다. 실기기에서 요청 중 비행기 모드를 켜면 dio 가 이 모양을
    // 준다 — 유형은 unknown, `error` 도 응답도 비어 있다 (#352 실측). SocketException
    // 을 넣어 만들면 실기기에서 안 나오는 친절한 모양만 검증하게 된다.
    if (body is FakeOffline) {
      throw DioException(requestOptions: options);
    }

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
fakeDioOverride(Map<String, Object?> routes, {Duration delay = Duration.zero}) {
  final dio = Dio(BaseOptions(baseUrl: 'https://test.local'))
    ..httpClientAdapter = FakeAdapter(routes, delay: delay);
  return dioProvider.overrideWithValue(dio);
}

/// 어떤 요청도 성공시키지 않는 Dio.
///
/// 네트워크를 쓰지 않는 화면을 검증할 때 쓴다 — 요청이 나가면 실패하므로,
/// 화면이 몰래 서버를 부르고 있었다면 그것이 드러난다.
// ignore: strict_top_level_inference
offlineDioOverride() => fakeDioOverride(const {});

/// 서버가 돌려주는 실패 한 건. [fakeDioOverride]의 값 자리에 넣는다.
///
/// ```dart
/// fakeDioOverride(const {
///   'POST /api/routines': FakeHttpError(
///     403,
///     errorCode: 'ROUTINE_CREATE_LIMIT_EXCEEDED',
///     errorMessage: '이번 주에 만들 수 있는 일과를 다 썼어요.',
///   ),
/// })
/// ```
class FakeHttpError {
  const FakeHttpError(this.status, {this.errorCode, this.errorMessage});

  final int status;
  final String? errorCode;
  final String? errorMessage;
}

/// 서버에 닿지 못한 요청 (비행기 모드). [fakeDioOverride]의 값 자리에 넣는다.
class FakeOffline {
  const FakeOffline();
}
