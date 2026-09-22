import 'package:dio/dio.dart';

import '../logger/app_logger.dart';
import 'app_failure.dart';

/// 실패를 **한 번만 해석해서** 실어 보낸다 — 서버 `@RestControllerAdvice` 의 반대편.
///
/// 서버는 던져진 예외를 한 곳에서 `{errorCode, errorMessage}` 로 바꿔 내려준다.
/// 이 인터셉터는 받는 쪽에서 그 반대를 한다 — 응답 본문을 한 번 읽어
/// [AppFailure] 로 바꾸고 `DioException.error` 에 실어 보낸다.
///
/// **그래서 호출부는 JSON 을 만지지 않는다.** 전에는
/// `(e.response!.data as Map)['errorCode']` 를 쓰는 곳마다 따로 적어, 본문이
/// 비거나 형식이 다르면 그 자리에서 깨졌다 (#347 · #352).
///
/// 로그도 여기서 한 줄로 남긴다. 화면마다 따로 남기면 실패 하나가 여러 줄로
/// 흩어져 무엇이 먼저 터졌는지 못 읽는다.
///
/// > ⚠️ **인터셉터 순서 — 맨 뒤에 붙인다.** 앞에 있는 인증 인터셉터가 토큰을
/// > 갱신해 요청을 되살리면(`handler.resolve`) 그건 실패가 아니다. 앞에 붙이면
/// > 되살아날 401 까지 실패로 로그가 남고, 점검 인터셉터의 판단보다 먼저 끼어든다.
class FailureInterceptor extends Interceptor {
  const FailureInterceptor();

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    // 이미 붙어 있으면 다시 계산하지 않는다 (재시도로 두 번 흐를 수 있다).
    if (err.error is AppFailure) return handler.next(err);

    final failure = AppFailure.of(err);

    // 앱이 스스로 끊은 요청은 실패가 아니다 — 로그를 남기면 진짜 실패가 묻힌다.
    if (!failure.isSilent) {
      // **없는 코드를 지어내지 않는다.** 전에는 `badgeOr('E-HTTP')` 를 썼는데,
      // 인터셉터는 화면 코드를 모르므로 아무것도 모를 때 `E-HTTP` 가 찍혔다.
      // 그 문자열은 코드베이스 어디에도 없어 제보를 받아도 찾을 수 없다 (#352).
      AppLogger.error('네트워크', failure, err.stackTrace, {
        'fault': failure.fault.name,
        if (failure.server != null && !failure.server!.isUnknownCode)
          'code': failure.server!.code.wire,
        'path': err.requestOptions.path,
        'status': err.response?.statusCode,
        // 서버가 준 문구는 사용자용이라 로그에 남겨도 안전하다.
        // **본문 전체는 남기지 않는다** — 보호자 입력 원문이 섞일 수 있다.
        if (failure.serverMessage != null) 'message': failure.serverMessage,
      });
    }

    handler.next(err.copyWith(error: failure));
  }
}
