import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/router/routes.dart';
import '../../profile/application/invite_inbox.dart';
import '../../profile/domain/invite_link.dart';

/// 연결 암호 링크로 받은 코드를 맡겨 두는 우편함. 초대 우편함과 같은 부품이고 인스턴스만 따로다 —
/// 두 링크가 서로의 코드를 덮지 않는다. 메모리에만 두는 이유도 같다 (10분짜리 자격증명).
final linkCodeInboxProvider = Provider<InviteInbox>((ref) {
  final inbox = InviteInbox();
  ref.onDispose(inbox.dispose);
  return inbox;
});

/// 링크를 열었는데 연결 암호를 넣을 수 없는 휴대폰일 때 알려 줄 내용.
enum LinkCodeNotice {
  /// 이미 이룸이 휴대폰으로 연결돼 있다.
  alreadyLinked,

  /// 보호자 휴대폰이다 — 연결 암호는 이룸이가 쓸 휴대폰에서 넣는다.
  openOnElumiPhone,
}

/// 열린 연결 암호 링크를 **알맞은 때에 암호 넣기 화면으로 이어 주는** 판단 ([InviteLinkIntake] 의 짝).
///
/// | 상황 | 동작 |
/// | --- | --- |
/// | 로그인된 이룸이 휴대폰 | 안내만 한다 (이미 연결됨) |
/// | 로그인된 보호자 휴대폰 | 안내만 한다 (이룸이 휴대폰에서 열기) |
/// | 로그인 전 | 우편함에 두고 로그인 화면에 닿으면 암호 넣기 화면을 연다 |
/// | 암호 넣기 화면이 이미 열려 있음 | 화면이 우편함을 듣고 있다가 바로 채운다 |
///
/// 연결 암호는 로그인 없이 넣는 코드라 로그인을 거치지 않는다. 채우기만 하고 **보내지 않는다** —
/// `시작하기`는 사람이 누른다.
class LinkCodeIntake {
  LinkCodeIntake({
    required this.inbox,
    required this.hasSession,
    required this.isElumiDevice,
    required this.topLocation,
    required this.open,
    required this.onNotice,
  });

  final InviteInbox inbox;
  final bool Function() hasSession;
  final bool Function() isElumiDevice;

  /// 지금 **맨 위에 보이는** 화면의 경로. 모르면 null.
  final String? Function() topLocation;

  /// 암호 넣기 화면을 연다 (로그인 화면 위에 얹는다).
  final void Function() open;

  final void Function(LinkCodeNotice notice) onNotice;

  /// 암호 넣기 화면을 열어도 되는 자리 — 세션이 없는 휴대폰이 서는 곳.
  static const readyLocations = {Routes.login};

  void accept(InviteLink link) {
    if (hasSession()) {
      onNotice(isElumiDevice() ? LinkCodeNotice.alreadyLinked : LinkCodeNotice.openOnElumiPhone);
      return;
    }
    inbox.receive(link.code);
    tryOpen();
  }

  /// 맡겨 둔 링크가 있고 열어도 되는 자리라면 암호 넣기 화면을 연다. 열었으면 true.
  bool tryOpen() {
    if (!inbox.hasPending) return false;
    // 링크를 받은 뒤 로그인했다면 더 이어 줄 이유가 없다
    if (hasSession()) {
      inbox.clear();
      return false;
    }
    if (!readyLocations.contains(topLocation())) return false;
    open();
    return true;
  }
}
