import '../../../core/network/app_failure.dart';
import '../../../core/network/server_error_code.dart';

/// 초대 코드 넣기가 실패한 **이유의 갈래** — 화면이 갈래마다 다르게 움직이도록 나눈다.
///
/// 문구는 여기서 짓지 않는다. 서버가 `errorMessage` 로 사용자용 문구를 주고 [AppFailure] 가
/// 그것을 우선 보여 준다. 갈래는 **다음 동작**을 정하는 데만 쓴다 — 입력을 비울지,
/// 새 코드를 받으라고 할지, 동의 화면으로 보낼지.
///
/// 서버 코드와 상태 코드 **둘 다** 본다. 프록시가 본문을 지우고 상태만 보내는 경우가 있다
/// (연결 암호 `DeviceLinkRepository._classify` 와 같은 이유).
enum InviteProblem {
  /// 없는 코드이거나 이미 쓴 코드 (404). 서버는 둘을 같은 문구로 준다.
  notFound,

  /// 10분이 지났다 (410).
  expired,

  /// 너무 많이 틀렸다 (429). 코드당 5번 · 계정당 10분 10번.
  tooManyAttempts,

  /// 이미 함께하는 이룸이다 (409). 자기가 만든 코드도 여기다. 코드는 쓰이지 않는다.
  alreadyGuardian,

  /// 약관에 먼저 동의해야 한다 (403).
  consentRequired,

  /// 이룸이 휴대폰에서는 할 수 없다 (403).
  forbiddenForElumi,

  /// 코드 모양이 서버 규칙에 맞지 않는다 (400).
  invalidInput,

  /// 서버에 닿지 못했다 (오프라인·시간 초과).
  offline,

  /// 그 밖의 실패.
  other;

  static InviteProblem of(AppFailure failure) {
    if (failure.isUnreachable) return offline;
    final server = failure.server;
    final status = server?.statusCode;
    switch (server?.code) {
      case ServerErrorCode.profileInviteNotFound:
        return notFound;
      case ServerErrorCode.profileInviteExpired:
        return expired;
      case ServerErrorCode.profileInviteTooManyAttempts:
        return tooManyAttempts;
      case ServerErrorCode.profileAlreadyGuardian:
        return alreadyGuardian;
      case ServerErrorCode.consentRequired:
        return consentRequired;
      case ServerErrorCode.deviceLinkForbiddenForElumi:
        return forbiddenForElumi;
      case ServerErrorCode.invalidInputValue:
        return invalidInput;
      default:
        break;
    }
    return switch (status) {
      404 => notFound,
      410 => expired,
      429 => tooManyAttempts,
      409 => alreadyGuardian,
      _ => other,
    };
  }
}
