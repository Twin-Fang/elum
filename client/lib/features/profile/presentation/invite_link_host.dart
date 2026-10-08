import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../application/invite_link_intake.dart';
import '../domain/invite_link.dart';

/// 앱이 켜져 있을 때 OS 가 밀어 넣는 초대 링크를 받아 [InviteLinkIntake] 에 넘긴다.
///
/// ## 왜 라우터가 아니라 여기서 먼저 받나
///
/// 켜져 있는 앱에 새 주소가 들어오면 go_router 는 그 주소로 **화면 스택을 다시 짠다.** 링크를 어느
/// 화면으로도 풀 수 없어 현재 자리로 되돌려도, 그 위에 쌓아 둔 화면(설정 하위·일과 만들기 단계)은
/// 사라진다 — 링크를 눌렀을 뿐인데 하던 일이 끊긴다. 그래서 [WidgetsBindingObserver] 로 라우터보다
/// **먼저** 받아, 초대 링크라면 여기서 처리하고(`true`) 라우터에는 알리지 않는다.
///
/// 라우터보다 앞서려면 이 위젯이 `MaterialApp.router` **위에** 있어야 한다. 관찰자는 등록한 순서대로
/// 불리고, 라우터의 관찰자는 라우터 위젯이 올라갈 때 등록된다.
///
/// 앱이 꺼져 있다 열리는 첫 링크(안드로이드의 초기 경로)는 이 길을 타지 않고 라우터의 리다이렉트가
/// 받는다 — `createRouter(onInviteLink:)`.
///
/// 화면 이동 때마다 [InviteLinkIntake.tryOpen] 을 다시 부른다 — 로그인·온보딩 중에 받은 링크는 알맞은
/// 자리에 닿았을 때 비로소 열린다.
class InviteLinkHost extends StatefulWidget {
  const InviteLinkHost({
    super.key,
    required this.router,
    required this.intake,
    required this.child,
  });

  final GoRouter router;
  final InviteLinkIntake intake;
  final Widget child;

  @override
  State<InviteLinkHost> createState() => _InviteLinkHostState();
}

class _InviteLinkHostState extends State<InviteLinkHost> with WidgetsBindingObserver {
  /// 열기를 이미 예약했다. 한 프레임에 두 번 얹지 않는다.
  bool _scheduled = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    widget.router.routerDelegate.addListener(_onRouteChanged);
  }

  @override
  void dispose() {
    widget.router.routerDelegate.removeListener(_onRouteChanged);
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Future<bool> didPushRouteInformation(RouteInformation routeInformation) async {
    final link = InviteLink.parse(routeInformation.uri);
    // 초대 링크가 아니면 건드리지 않는다 — 소셜 로그인 콜백·다른 라우트는 라우터가 받는다.
    if (link == null) return false;
    widget.intake.accept(link);
    return true;
  }

  void _onRouteChanged() {
    if (_scheduled) return;
    _scheduled = true;
    // 화면 이동 도중에 또 이동하지 않는다 — 이동이 끝난 프레임 뒤에 연다.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scheduled = false;
      if (!mounted) return;
      widget.intake.tryOpen();
    });
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
