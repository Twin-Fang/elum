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

  /// 다음에 무엇을 하면 되는지. **네트워크 쪽 사정은 서버가 말해 줄 수 없다.**
  ///
  /// 실기기에서 비행기 모드로 밟아 보니 화면이 이렇게 말하고 있었다.
  ///
  /// ```
  /// 일과를 불러오지 못했어요
  /// 다시 시도 (E-NET-OFFLINE)
  /// ```
  ///
  /// 코드는 **개발자에게** 네트워크라고 말하는데 **사용자에게는** 아무 말도 안 한다.
  /// 인터넷을 확인하라는 말이 없으니 끊긴 채로 계속 다시 시도를 누른다.
  /// 세어 보니 인터넷을 언급하는 화면이 로그인·암호넣기 **둘뿐**이었다 — 화면마다
  /// 따로 쓰게 두면 나머지는 영영 안 쓴다. 그래서 여기서 한 번만 말한다 (#352).
  String? get hint => switch (fault) {
    NetworkFault.offline => '인터넷 연결을 확인해주세요',
    NetworkFault.timeout => '연결이 느려요. 잠시 후 다시 해주세요',
    NetworkFault.badCertificate => '안전하지 않은 연결이에요. 다른 망에서 해주세요',
    _ => null,
  };

  /// 서버에 **닿지 못했다** — 오프라인·타임아웃·인증서. 사용자가 할 일이 있는 실패다
  /// ([hint] 가 있다). 서버가 응답한 실패와 달리 다음 요청도 같은 이유로 실패한다.
  bool get isUnreachable => switch (fault) {
    NetworkFault.offline ||
    NetworkFault.timeout ||
    NetworkFault.badCertificate => true,
    NetworkFault.cancelled || NetworkFault.none || NetworkFault.app => false,
  };

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

  /// 한 줄로 말한다 — `무엇이 안 됐는지 · 무엇을 하면 되는지 (식별자)`.
  ///
  /// 서버가 이유를 말해 줬으면 그것으로 충분하다. 말이 없고 네트워크 사정을
  /// 아는 경우에만 [hint] 를 덧붙인다 — 무엇이 안 됐는지(화면 몫)와 무엇을 하면
  /// 되는지(여기 몫)가 둘 다 있어야 사용자가 다음 수를 안다.
  String describe(String fallback, String fallbackCode) {
    final body = serverMessage ??
        (hint == null ? fallback : '$fallback · $hint');
    return '$body (${badgeOr(fallbackCode)})';
  }

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
        // **응답이 없으면 서버에 닿지 못한 것이다.**
        //
        // 원래는 `e.error is SocketException` 으로만 갈랐는데, 실기기에서
        // 요청이 나가는 도중에 비행기 모드를 켜면 dio 가 `error` 를 비운 채
        // `DioException [unknown]: null` 을 준다 (2026-09-23 실측). 그러면
        // 연결 실패가 `앱 오류` 로 떨어져 "다시 해주세요" 로 안내하게 된다 —
        // 오프라인인 사용자는 될 때까지 계속 누른다 (#341 이 지적한 그 상황).
        //
        // 타입이 아니라 **응답 유무**로 가른다. 응답을 못 받았다는 사실이
        // 원인을 모르는 것보다 확실하다.
        if (e.response == null) {
          return AppFailure(fault: NetworkFault.offline, cause: e);
        }
        // 응답이 있는데 unknown 이면 앱 쪽 문제다 — 본문은 읽어 둔다.
        return AppFailure(
          fault: NetworkFault.app,
          server: e.serverError,
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
