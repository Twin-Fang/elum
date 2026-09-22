import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';

import 'server_error.dart';
import 'server_error_code.dart';

/// 응답 자체가 없거나 서버 코드로 설명되지 않는 실패.
///
/// 서버 코드 enum([ServerErrorCode])에 **넣지 않는다.** 그 enum 은 서버
/// `ErrorCode.java` 와 1:1 이고 `server_error_sync_test.dart` 가 그것을 지킨다.
/// 연결 실패는 서버가 모르는 일이므로 여기에 따로 둔다.
enum NetworkFault {
  /// 인터넷이 없거나 서버에 닿지 못했다.
  offline('E-NET-OFFLINE'),

  /// 닿긴 했는데 제때 못 받았다.
  timeout('E-NET-TIMEOUT'),

  /// 앱이 스스로 끊었다 (화면을 떠나는 등). **사용자에게 알리지 않는다.**
  cancelled('E-NET-CANCEL'),

  /// 인증서 문제. 공용 와이파이의 가로채기 페이지에서 실제로 난다.
  badCertificate('E-NET-CERT'),

  /// 서버가 응답은 했다 — 무엇이 문제인지는 [ServerErrorCode] 가 말한다.
  none(''),

  /// 네트워크 밖에서 터졌다 (파싱 실패·상태 오류 등).
  app('E-APP');

  const NetworkFault(this.wire);

  final String wire;
}

/// 앱이 만나는 **모든 실패**를 한 모양으로 담는다.
///
/// ## 왜 필요한가 — 서버에는 있는 것이 앱에는 없었다
///
/// 서버는 `@RestControllerAdvice` **한 곳**에서 모든 예외를
/// `{errorCode, errorMessage}` 로 바꿔 내려준다. 컨트롤러는 그냥 던지면 된다.
///
/// 앱에는 그 대칭이 없었다. [ServerError] 를 만들어 두고도 **호출부가 각자
/// 붙여야 해서** 두 군데밖에 안 붙었고, 나머지 21개 파일은 자기 문구를 지었다.
/// 그래서 서버가 `MEMBER_SUSPENDED`("정지된 계정이에요")를 보내도 화면에는
/// "잠시 후 다시 해주세요"가 떴다 (#352).
///
/// 이 클래스가 그 판정을 **한 곳으로** 모은다. 무엇이 던져지든 받는다 —
/// `DioException`·타임아웃·소켓 오류·그 밖의 예외.
///
/// ```dart
/// } catch (e) {
///   final f = AppFailure.of(e);
///   showFailure(context, f, fallback: '일과를 불러오지 못했어요', fallbackCode: 'E-RT');
/// }
/// ```
///
/// ## 기본 문구를 없애지 않는다
///
/// 서버가 문구를 못 줄 수도 있고(연결 실패·예상 못 한 예외), 화면마다 맥락이
/// 다르다. **기본 문구는 화면이 넘기되, 서버 문구가 있으면 항상 그쪽이 이긴다.**
class AppFailure {
  const AppFailure({
    required this.fault,
    this.server,
    this.cause,
  });

  /// 네트워크 쪽 사정. 서버가 응답했으면 [NetworkFault.none].
  final NetworkFault fault;

  /// 서버가 보낸 실패. 응답이 없었으면 null.
  final ServerError? server;

  /// 원래 예외. 로그에만 쓴다 — 화면에 보여주지 않는다.
  final Object? cause;

  /// 사용자에게 스스로 알리지 않는 실패.
  ///
  /// 앱이 끊은 요청(화면 이탈 등)까지 팝업을 띄우면, 사용자는 자기가 한 적 없는
  /// 실패를 본다.
  bool get isSilent => fault == NetworkFault.cancelled;

  /// 서버가 준 사용자용 문구. 없으면 null.
  String? get serverMessage => server?.message?.trim().isEmpty ?? true
      ? null
      : server!.message!.trim();

  /// 화면에 띄울 문구. **서버 것이 있으면 그것을 그대로 쓴다.**
  ///
  /// 서버 문구는 이미 사용자용으로 쓰여 있고 해요체·용어 규칙까지 맞춰져 있다.
  /// 앱이 다시 쓰면 서버에서 고쳐도 앱은 옛 문구를 보여준다.
  String messageOr(String fallback) => serverMessage ?? fallback;

  /// 추적용 식별자. 사용자에게는 뜻이 없지만, 제보를 받았을 때 어디서 터졌는지
  /// 가릴 유일한 단서다 (docs 예외처리 규칙).
  ///
  /// 순서는 **구체적인 것부터**다.
  ///
  /// | 아는 것 | 배지 | 왜 |
  /// |---|---|---|
  /// | 서버 코드 | `MEMBER_SUSPENDED` | 무엇이 문제인지까지 말한다 |
  /// | 연결 실패 | `E-NET-OFFLINE` | 서버 잘못이 아니다 |
  /// | 상태 코드만 | `E-1001/500` | **자리와 종류를 함께** 남긴다 |
  /// | 아무것도 | `E-1001` | 화면이 준 자리 코드 |
  ///
  /// 상태 코드만 알 때 `E-HTTP-500` 처럼 종류만 남기면 **어느 화면에서 터졌는지를
  /// 잃는다.** 제보를 받은 사람은 코드로 코드베이스를 찾는데, `E-HTTP-500` 은
  /// 어디에도 없다. 그래서 화면 코드를 앞에 두고 상태를 뒤에 붙인다.
  String badgeOr(String fallbackCode) {
    if (fault != NetworkFault.none && fault != NetworkFault.app) {
      return fault.wire;
    }
    final s = server;
    if (s != null && !s.isUnknownCode) return s.code.wire;
    if (s?.statusCode != null) return '$fallbackCode/${s!.statusCode}';
    return fallbackCode;
  }

  /// 팝업 본문 한 줄 — `문구 (식별자)`.
  String describe(String fallback, String fallbackCode) =>
      '${messageOr(fallback)} (${badgeOr(fallbackCode)})';

  /// **무엇이 던져져도 받는다.** 이 함수가 앱의 단일 판정 지점이다.
  ///
  /// 이미 [AppFailure] 면 그대로 돌려준다 — 인터셉터가 한 번 판정해 붙여 두면
  /// 여기서 다시 계산하지 않는다.
  factory AppFailure.of(Object? error) {
    if (error is AppFailure) return error;

    if (error is DioException) {
      // 인터셉터가 이미 판정해 붙여 뒀으면 그것을 쓴다.
      final attached = error.error;
      if (attached is AppFailure) return attached;
      return AppFailure._fromDio(error);
    }

    if (error is TimeoutException) {
      return AppFailure(fault: NetworkFault.timeout, cause: error);
    }
    if (error is SocketException) {
      return AppFailure(fault: NetworkFault.offline, cause: error);
    }
    return AppFailure(fault: NetworkFault.app, cause: error);
  }

  /// **`default` 를 두지 않는다.** dio 가 새 실패 유형을 더하면 여기서 컴파일이
  /// 막혀 사람이 판단하게 된다. 조용히 `앱 오류` 로 뭉뚱그려지면 아무도 모른다.
  factory AppFailure._fromDio(DioException e) {
    switch (e.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
      // 본문 변환이 오래 걸려 끊긴 경우. 사용자에게는 나머지 셋과 같은 말이다.
      case DioExceptionType.transformTimeout:
        return AppFailure(fault: NetworkFault.timeout, cause: e);
      case DioExceptionType.connectionError:
        return AppFailure(fault: NetworkFault.offline, cause: e);
      case DioExceptionType.cancel:
        return AppFailure(fault: NetworkFault.cancelled, cause: e);
      case DioExceptionType.badCertificate:
        return AppFailure(fault: NetworkFault.badCertificate, cause: e);
      case DioExceptionType.badResponse:
        return AppFailure(
          fault: NetworkFault.none,
          server: e.serverError,
          cause: e,
        );
      case DioExceptionType.unknown:
        // dio 는 원인을 모를 때 원래 예외를 `error` 에 넣어 준다.
        // 기기가 비행기 모드면 여기로 `SocketException` 이 온다.
        if (e.error is SocketException) {
          return AppFailure(fault: NetworkFault.offline, cause: e);
        }
        // 응답이 있는데 unknown 인 경우도 있다 — 본문은 읽어 둔다.
        return AppFailure(
          fault: NetworkFault.app,
          server: e.response == null ? null : e.serverError,
          cause: e,
        );
    }
  }

  @override
  String toString() =>
      'AppFailure(${fault.name}${server == null ? '' : ', $server'})';
}


/// 성공값 아니면 실패 — 저장소가 **예외를 삼키면서도 이유는 잃지 않게** 한다.
///
/// 이 앱의 저장소는 예외를 올리지 않는다(호출부마다 catch 가 흩어지고 화면이
/// 죽는다). 그러다 보니 실패가 `null` 이나 `false` 로 납작해져 **서버가 알려준
/// 이유가 저장소 안에서 사라졌다.** 그래서 값과 실패를 함께 돌려준다 (#352).
///
/// ```dart
/// final r = await repo.issue();
/// if (r.isOk) use(r.value!);
/// else showFailure(context, r.failure, ...);
/// ```
class Attempt<T> {
  const Attempt.ok(T this.value) : failure = null;
  const Attempt.failed(AppFailure this.failure) : value = null;

  final T? value;
  final AppFailure? failure;

  bool get isOk => failure == null;
}
