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

/// 열린 연결 암호 링크의 코드를 **암호 넣기 화면이 꺼내 갈 때까지 맡겨 두는** 판단 ([InviteLinkIntake] 의 짝).
///
/// | 상황 | 동작 |
/// | --- | --- |
/// | 로그인된 이룸이 휴대폰 | 안내만 한다 (이미 연결됨) |
/// | 가입 중(동의·역할 선택·암호 넣기) | 우편함에 둔다 |
/// | 그 밖의 로그인된 휴대폰 | 안내만 한다 (이룸이 휴대폰에서 열기) |
/// | 로그인 전 | 우편함에 두기만 한다 |
///
/// 암호 넣기 화면을 **여기서 열지 않는다.** 이룸이 휴대폰도 로그인하고 역할 선택에서 이룸이를 고른 뒤에
/// 그 화면에 닿고, 화면이 열리면서(또는 열려 있다가) 우편함의 코드를 채운다. 채우기만 하고 **보내지 않는다** —
/// `시작하기`는 사람이 누른다.
class LinkCodeIntake {
  LinkCodeIntake({
    required this.inbox,
    required this.hasSession,
    required this.isElumiDevice,
    required this.topLocation,
    required this.onNotice,
  });

  final InviteInbox inbox;
  final bool Function() hasSession;
  final bool Function() isElumiDevice;

  /// 지금 **맨 위에 보이는** 화면의 경로. 모르면 null.
  final String? Function() topLocation;

  final void Function(LinkCodeNotice notice) onNotice;

  /// 로그인한 뒤 이룸이 휴대폰 연결로 가는 가입 단계 — 여기 서 있으면 링크를 맡아 둔다.
  static const signUpLocations = {
    Routes.consent,
    Routes.roleSelect,
    Routes.linkEnter,
  };

  void accept(InviteLink link) {
    if (hasSession()) {
      if (isElumiDevice()) {
        onNotice(LinkCodeNotice.alreadyLinked);
        return;
      }
      if (!signUpLocations.contains(topLocation())) {
        onNotice(LinkCodeNotice.openOnElumiPhone);
        return;
      }
    }
    inbox.receive(link.code);
  }

  /// 화면을 옮길 때마다 불린다. 연결을 마친 휴대폰에 남은 코드는 버린다. 화면은 열지 않는다.
  bool tryOpen() {
    if (inbox.hasPending && hasSession() && isElumiDevice()) inbox.clear();
    return false;
  }
}
