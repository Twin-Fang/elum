import 'package:dio/dio.dart';

import 'server_error_code.dart';

/// 서버가 보낸 실패 한 건.
///
/// 서버는 `{ "errorCode": ..., "errorMessage": ... }`를 내려준다. 이걸 꺼내는 일을
/// **여기 한 곳에만** 둔다. 예전에는 `(e.response!.data as Map)['errorCode']`를
/// 쓰는 곳마다 따로 적어, 본문이 비거나 형식이 다르면 그 자리에서 깨졌다 (#347).
class ServerError {
  const ServerError({required this.code, this.message, this.statusCode});

  final ServerErrorCode code;

  /// 서버가 준 사용자용 문구. **이게 있으면 이걸 그대로 보여주는 것이 기본이다.**
  ///
  /// 서버 문구는 이미 사용자용으로 쓰여 있고 해요체·용어 규칙까지 맞춰져 있다.
  /// 앱이 다시 쓰면 서버에서 고쳐도 앱은 옛 문구를 보여준다.
  final String? message;

  final int? statusCode;

  /// 앱이 모르는 코드인가 — **서버가 새 코드를 먼저 배포하면 반드시 생긴다.**
  /// 그때도 [message]는 맞으므로 문구는 그대로 쓸 수 있다.
  bool get isUnknownCode => code == ServerErrorCode.unknown;

  /// 사용자에게 보여줄 문구. 서버 것이 없으면 [fallback]을 쓴다.
  String messageOr(String fallback) {
    final m = message?.trim();
    return (m == null || m.isEmpty) ? fallback : m;
  }

  /// 화면에 함께 붙일 식별자. 코드를 모르면 상태 코드라도 남긴다 —
  /// 제보를 받았을 때 추적할 유일한 단서다.
  String get badge => isUnknownCode ? 'E-HTTP-${statusCode ?? 0}' : code.wire;

  @override
  String toString() => '${code.wire}($statusCode): $message';
}

extension DioServerError on DioException {
  /// 응답 본문에서 서버 에러를 꺼낸다.
  ///
  /// **어떤 모양이 와도 던지지 않는다.** 본문이 비었거나, Map이 아니거나, 필드가
  /// 없어도 [ServerErrorCode.unknown]으로 돌아온다. 실패를 알리려다 앱이 죽으면
  /// 사용자는 무슨 일이 났는지조차 모른다.
  ServerError get serverError {
    final data = response?.data;
    if (data is! Map) {
      return ServerError(
        code: ServerErrorCode.unknown,
        statusCode: response?.statusCode,
      );
    }
    return ServerError(
      code: ServerErrorCode.from(data['errorCode']?.toString()),
      message: data['errorMessage']?.toString(),
      statusCode: response?.statusCode,
    );
  }
}
