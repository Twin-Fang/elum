import 'package:flutter/material.dart';

/// 정리 상태 끝내기: `완료` 말고도 홈 화면처럼 빠져나온다
/// 경로 4개: 뒤로가기, 빈 곳 누르기, 다른 칸(탭)으로 가기, 앱 내리기. 정리 상태가 아니면 그대로 지나간다
class LibraryArrangeExitScope extends StatefulWidget {
  const LibraryArrangeExitScope({
    super.key,
    required this.isArranging,
    required this.onExit,
    required this.child,
  });

  final bool isArranging;
  final VoidCallback onExit;
  final Widget child;

  @override
  State<LibraryArrangeExitScope> createState() =>
      _LibraryArrangeExitScopeState();
}

class _LibraryArrangeExitScopeState extends State<LibraryArrangeExitScope> {
  late final AppLifecycleListener _lifecycleListener;

  @override
  void initState() {
    super.initState();
    _lifecycleListener = AppLifecycleListener(onHide: _exitIfArranging);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // 탭 화면은 안 보이는 동안에도 살아 있다 — 다른 칸으로 가면(TickerMode 꺼짐) 끝낸다
    if (!TickerMode.of(context)) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _exitIfArranging());
    }
  }

  @override
  void dispose() {
    _lifecycleListener.dispose();
    super.dispose();
  }

  void _exitIfArranging() {
    if (mounted && widget.isArranging) widget.onExit();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      // 하단 바 첫 화면이라 그냥 두면 뒤로가기가 앱을 닫는다
      canPop: !widget.isArranging,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _exitIfArranging();
      },
      // 칸 · ⊖ · 머리 버튼은 제 탭이 먼저 이기므로 빈 곳을 누를 때만 닿는다
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.isArranging ? widget.onExit : null,
        child: widget.child,
      ),
    );
  }
}
