import 'package:flutter_riverpod/flutter_riverpod.dart';

/// 세션이 끝났음을 앱 전역에 알린다.
///
/// 토큰 갱신까지 실패하면 더 이상 서버와 아무것도 주고받을 수 없다. 그런데 화면은
/// 로컬 캐시로 계속 그려져서, 사용자는 로그인이 풀린 줄 모른 채 쓰게 된다 (이슈 #175).
///
/// 라우터 가드로는 잡히지 않는다 — 가드는 **화면을 옮길 때** 평가되므로 이미 홈에
/// 머무는 중이면 다시 불리지 않는다. 그래서 신호를 따로 흘려보내고, 화면 쪽에서
/// 그 신호를 보고 로그인으로 되돌린다.
///
/// 값은 "몇 번째 만료인가"다. 같은 세션에서 두 번 만료될 수 있으므로 bool이 아니라
/// 증가하는 수를 쓴다 — bool이면 두 번째 만료를 구분하지 못한다.
class SessionExpiryNotifier extends Notifier<int> {
  @override
  int build() => 0;

  /// 세션이 끝났다. 듣고 있는 화면이 로그인으로 되돌린다.
  void markExpired() => state = state + 1;
}

final sessionExpiryProvider =
    NotifierProvider<SessionExpiryNotifier, int>(SessionExpiryNotifier.new);
