import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/widgets/periodic_refresh.dart';
import '../../member/application/member_providers.dart';
import '../../guardian/application/routine_providers.dart';

/// 이룸이·보호자 홈이 떠 있는 동안 오늘 일과와 회원 정보(누적 별)를 주기적으로 다시 받는다.
///
/// 보호자가 일과를 저장하거나 다른 휴대폰에서 별이 올라도 알려줄 길이 없다(푸시·소켓 없음).
/// 홈이 한 번 받은 값을 계속 쥐고 있어 앱을 껐다 켜야 새 값이 보였다.
///
/// - 카드 상세를 보고 있어도 갱신한다. 상세는 열 때 받은 값이 아니라 이 목록에서
///   id로 다시 찾아 그리므로, 보호자가 이미 있는 일과를 고쳐도 반영된다.
/// - 화면에 들어올 때 이미 받아 둔 목록이 있으면 곧바로 한 번 다시 받는다.
///   목록은 보호자·이룸이 화면이 함께 쓰므로, 앞 화면에서 받아 둔 옛 목록을 그대로 이어받아
///   첫 주기(30초)까지 새 일과가 안 보였다. 아직 한 번도 안 받았으면 화면이 구독하며
///   받으므로 두 번 부르지 않는다.
/// - 일과는 `invalidate`라 직전 목록을 쥔 채 다시 받는다 — 깜빡이지 않고 실패해도 직전 목록이 남는다.
/// - 회원 정보는 [refreshMemberQuietly] 로 받는다 — 실패(오프라인)면 마지막 값을 그대로 두고,
///   값이 달라졌을 때만 반영한다.
class RoutineAutoRefresh extends ConsumerStatefulWidget {
  const RoutineAutoRefresh({
    super.key,
    required this.child,
    this.interval = const Duration(seconds: 30),
  });

  final Widget child;
  final Duration interval;

  @override
  ConsumerState<RoutineAutoRefresh> createState() => _RoutineAutoRefreshState();
}

class _RoutineAutoRefreshState extends ConsumerState<RoutineAutoRefresh> {
  /// 회원 정보 요청이 돌아오기 전에 다음 주기가 와도 겹쳐 보내지 않는다.
  bool _memberBusy = false;

  void _refresh() {
    if (!mounted) return;
    // 응답이 주기보다 느리면 요청이 쌓이고 먼저 보낸 것은 버려진다 — 받는 중이면 건너뛴다.
    if (!ref.read(todayRoutinesProvider).isLoading) {
      ref.invalidate(todayRoutinesProvider);
    }
    _refreshMember();
  }

  Future<void> _refreshMember() async {
    if (_memberBusy) return;
    _memberBusy = true;
    try {
      await refreshMemberQuietly(ref, isMounted: () => mounted);
    } finally {
      _memberBusy = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return PeriodicRefresh(
      interval: widget.interval,
      onRefresh: _refresh,
      refreshOnEnter: ref.read(todayRoutinesProvider).hasValue,
      child: widget.child,
    );
  }
}
