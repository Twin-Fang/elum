import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// 링크로 받은 초대 코드 하나.
@immutable
class PendingInvite {
  const PendingInvite({required this.code, required this.receivedAt});

  /// 정규화한 코드. 링크는 맞는데 코드를 못 쓸 모양이면 null — 화면이 에러 안내를 띄운다.
  final String? code;

  final DateTime receivedAt;
}

/// 링크로 받은 초대 코드를 **알맞은 때까지 들고 있는** 우편함.
///
/// 링크는 아무 때나 열린다 — 앱이 꺼져 있을 때, 로그인 전, 온보딩 도중, 다른 일을 하던 중에도.
/// 그때마다 화면을 바로 덮으면 하던 일이 날아가고, 그냥 버리면 받은 사람이 링크를 다시 눌러야 한다.
/// 그래서 코드를 여기에 두고 **입력 화면을 열 수 있는 자리**에 왔을 때 꺼낸다.
///
/// ## 왜 메모리에만 두나
///
/// 초대 코드는 10분짜리 자격증명이다. 디스크(SharedPreferences)에 남기면 만료 뒤에도 흔적이
/// 남고 앱이 지워질 때까지 평문으로 있다. 앱이 죽었다 켜지는 경우는 링크를 다시 누르면 되는 쪽이
/// 훨씬 싸다. 서버 로그·분석·로그 파일에도 코드를 남기지 않는다.
///
/// ## 만료
///
/// 서버 코드의 유효 시간([ttl], 10분)이 지나면 버린다. 이미 못 쓰는 코드를 채워 놓고 서버에서
/// 만료 에러를 받게 하는 것보다, 처음부터 빈 입력 화면을 여는 편이 낫다.
///
/// 상태관리 대신 [ChangeNotifier] 를 쓴다 — 화면이 `initState` 에서 꺼낼 때(`take`) 값이 바뀌는데,
/// Riverpod 은 위젯을 짓는 도중에 provider 상태를 바꾸는 것을 막는다.
class InviteInbox extends ChangeNotifier {
  InviteInbox({DateTime Function()? now, this.ttl = const Duration(minutes: 10)})
    : _now = now ?? DateTime.now;

  final DateTime Function() _now;

  /// 서버가 초대 코드를 쓸 수 있게 두는 시간(`CodeDigest.CODE_TTL`)과 같다.
  final Duration ttl;

  PendingInvite? _pending;

  /// 꺼내지 않은 코드가 있는가. 만료된 것은 없는 것으로 친다.
  bool get hasPending => _live() != null;

  /// 링크를 받았다. 먼저 받은 것이 있어도 **나중 것으로 바꾼다** — 보호자가 코드를 다시 만들면 앞 코드는
  /// 서버에서 폐기되므로 가장 최근 링크만 쓸 수 있다.
  ///
  /// [code] 는 [InviteLink.parse] 가 정규화한 값이거나, 못 쓸 모양이면 null.
  void receive(String? code) {
    _pending = PendingInvite(code: code, receivedAt: _now());
    notifyListeners();
  }

  /// 꺼내면서 비운다. 한 번 꺼낸 코드는 다시 나오지 않는다 — 같은 코드를 두 번 보내면 두 번째는 409 다.
  PendingInvite? take() {
    final live = _live();
    _pending = null;
    return live;
  }

  /// 버린다 (이룸이 휴대폰에서 받았거나 더 쓸 이유가 없을 때). 알리지 않는다 — 값이 사라지는 것에 반응할 곳이 없다.
  void clear() => _pending = null;

  PendingInvite? _live() {
    final p = _pending;
    if (p == null) return null;
    if (_now().difference(p.receivedAt) >= ttl) {
      _pending = null;
      return null;
    }
    return p;
  }
}

final inviteInboxProvider = Provider<InviteInbox>((ref) {
  final inbox = InviteInbox();
  ref.onDispose(inbox.dispose);
  return inbox;
});
