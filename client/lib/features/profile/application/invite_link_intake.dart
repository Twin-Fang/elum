import '../domain/invite_link.dart';
import 'invite_inbox.dart';
import '../../../core/router/routes.dart';

/// 열린 초대 링크를 **알맞은 때에 입력 화면으로 이어 주는** 판단 (#365).
///
/// 링크는 아무 때나 열린다. 이 클래스는 두 가지만 정한다.
///
/// 1. **받을지** — 이룸이 휴대폰에서 열린 링크는 받지 않고 안내만 한다. 이룸이 휴대폰은 초대를 받을 수 없고
///    (서버도 403), 이룸이에게 보호자용 입력 화면을 보여 줄 이유가 없다.
/// 2. **언제 열지** — 우편함에 맡겨 두었다가 [readyLocations] 에 사람이 서 있을 때 연다.
///
/// | 상황 | 동작 |
/// | --- | --- |
/// | 앱이 꺼져 있다 열림 | 시작 화면이 갈 곳을 정한다 → 보호자 홈에 닿으면 연다 |
/// | 로그인 전 | 우편함에 둔다 → 로그인·약관·역할을 마치고 이름 화면에 닿으면 연다 |
/// | 온보딩 도중 | 이름 화면에서만 연다 (그 뒤 단계에서 가로채지 않는다) |
/// | 보호자 홈 | 바로 연다 |
/// | 그 밖의 화면(일과 만들기·설정 등) | 하던 일을 끊지 않는다. 홈에 돌아오면 연다 (10분 안) |
/// | 입력 화면이 이미 열려 있음 | 화면이 우편함을 듣고 있다가 바로 채운다 |
///
/// ## 왜 이 두 곳인가
///
/// 입력 화면은 "뒤로 갈 곳이 있는" 자리에 얹어야 한다. 이름 화면은 이미 `초대 코드가 있어요` 로
/// 같은 입력 화면을 여는 자리이고, 보호자 홈은 설정의 `함께하는 사람` 이 여는 자리와 같은 뿌리다.
/// 합류하면 어느 쪽이든 보호자 홈으로 간다.
class InviteLinkIntake {
  InviteLinkIntake({
    required this.inbox,
    required this.isElumiDevice,
    required this.hasSession,
    required this.topLocation,
    required this.open,
    this.onElumiDeviceRejected,
  });

  final InviteInbox inbox;
  final bool Function() isElumiDevice;
  final bool Function() hasSession;

  /// 지금 **맨 위에 보이는** 화면의 경로. 위에 쌓은 화면까지 센다. 모르면 null.
  final String? Function() topLocation;

  /// 입력 화면을 연다 (보던 화면 위에 얹는다).
  final void Function() open;

  /// 이룸이 휴대폰에서 열린 링크를 받지 않았을 때 — 조용히 넘기지 않고 이유를 알린다.
  final void Function()? onElumiDeviceRejected;

  /// 입력 화면을 열어도 되는 자리.
  static const readyLocations = {Routes.guardian, Routes.onboardingName};

  /// 링크가 열렸다.
  void accept(InviteLink link) {
    // 이룸이 휴대폰은 우편함에 두지 않고 이유만 알린다.
    if (isElumiDevice()) {
      onElumiDeviceRejected?.call();
      return;
    }
    inbox.receive(link.code);
    tryOpen();
  }

  /// 맡겨 둔 링크가 있고 열어도 되는 자리라면 입력 화면을 연다. 열었으면 true.
  bool tryOpen() {
    if (!inbox.hasPending) return false;
    if (isElumiDevice()) {
      // 링크를 받은 뒤 이룸이 휴대폰이 되었다면(연결) 더 이어 줄 이유가 없다
      inbox.clear();
      return false;
    }
    if (!hasSession()) return false;
    if (!readyLocations.contains(topLocation())) return false;
    open();
    return true;
  }
}
