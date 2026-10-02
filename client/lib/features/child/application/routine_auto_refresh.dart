import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../guardian/data/routine_repository.dart';

/// 이룸이 홈이 떠 있는 동안 오늘 일과를 주기적으로 다시 받는다 (이슈 #517).
///
/// 보호자가 일과를 저장해도 이룸이 폰에는 알려줄 길이 없다(푸시·소켓 없음).
/// 홈이 한 번 받은 목록을 계속 쥐고 있어 앱을 껐다 켜야 새 일과가 보였다.
///
/// - 카드 상세를 보고 있어도 갱신한다. 상세는 열 때 받은 값이 아니라 이 목록에서
///   id로 다시 찾아 그리므로, 보호자가 이미 있는 일과를 고쳐도 반영된다.
/// - 화면에 들어올 때 이미 받아 둔 목록이 있으면 곧바로 한 번 다시 받는다 (이슈 #541).
///   목록은 보호자·이룸이 화면이 함께 쓰므로, 보호자 화면에서 받아 둔 옛 목록을
///   이룸이 화면이 그대로 이어받아 첫 주기(30초)까지 새 일과가 안 보였다.
///   아직 한 번도 안 받았으면 화면이 구독하며 받으므로 두 번 부르지 않는다.
/// - 백그라운드에서는 멈춘다 — OS가 타이머를 막고 보는 사람도 없다.
///   돌아오면([AppLifecycleState.resumed]) 즉시 한 번 받고 주기를 다시 시작한다.
/// - 갱신은 `invalidate`다. 직전 목록을 쥔 채 다시 받으므로 깜빡이지 않고,
///   실패해도 직전 목록이 남는다.
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

class _RoutineAutoRefreshState extends ConsumerState<RoutineAutoRefresh>
    with WidgetsBindingObserver {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _start();
    // 이미 받아 둔 목록은 다른 화면에서 받은 옛것일 수 있다 — 들어오자마자 다시 받는다.
    // initState 안에서 provider 를 바꾸면 안 되므로 첫 프레임 뒤에 부른다.
    if (ref.read(todayRoutinesProvider).hasValue) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _refresh());
    }
  }

  void _start() {
    _timer?.cancel();
    _timer = Timer.periodic(widget.interval, (_) => _refresh());
  }

  void _refresh() {
    if (!mounted) return;
    // 응답이 주기보다 느리면 요청이 쌓이고 먼저 보낸 것은 버려진다 — 받는 중이면 건너뛴다.
    if (ref.read(todayRoutinesProvider).isLoading) return;
    ref.invalidate(todayRoutinesProvider);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _refresh();
      _start();
    } else if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden) {
      _timer?.cancel();
      _timer = null;
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
