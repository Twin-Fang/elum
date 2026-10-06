import 'dart:async';

import 'package:flutter/widgets.dart';

/// 화면이 떠 있는 동안 [onRefresh] 를 주기적으로 부른다.
///
/// 푸시·소켓이 없어 다른 휴대폰의 변경은 다시 받아야만 보인다. 일과·별·함께하는 사람 목록이
/// 같은 규칙으로 갱신되도록 타이머·생명주기 처리를 한 곳에 둔다.
///
/// - 백그라운드에서는 멈춘다 — OS가 타이머를 막고 보는 사람도 없다.
///   돌아오면([AppLifecycleState.resumed]) 즉시 한 번 부르고 주기를 다시 시작한다.
/// - [refreshOnEnter] 가 true 면 첫 프레임 뒤 곧바로 한 번 부른다. 앞 화면이 받아 둔 값이
///   옛것일 수 있을 때 첫 주기까지 기다리지 않게 한다.
/// - 요청이 겹치지 않게 하는 것은 [onRefresh] 의 몫이다(받는 중이면 건너뛴다).
class PeriodicRefresh extends StatefulWidget {
  const PeriodicRefresh({
    super.key,
    required this.onRefresh,
    required this.child,
    this.interval = const Duration(seconds: 30),
    this.refreshOnEnter = false,
  });

  final VoidCallback onRefresh;
  final Widget child;
  final Duration interval;
  final bool refreshOnEnter;

  @override
  State<PeriodicRefresh> createState() => _PeriodicRefreshState();
}

class _PeriodicRefreshState extends State<PeriodicRefresh>
    with WidgetsBindingObserver {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _start();
    if (widget.refreshOnEnter) {
      // initState 안에서 provider 를 바꾸면 안 되므로 첫 프레임 뒤에 부른다.
      WidgetsBinding.instance.addPostFrameCallback((_) => _refresh());
    }
  }

  void _start() {
    _timer?.cancel();
    _timer = Timer.periodic(widget.interval, (_) => _refresh());
  }

  void _refresh() {
    if (!mounted) return;
    widget.onRefresh();
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
