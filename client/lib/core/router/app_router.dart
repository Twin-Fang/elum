import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../features/profile/domain/invite_link.dart';
import '../config/app_config.dart';
import '../l10n/l10n_context.dart';
import 'route_redirect.dart';
import 'routes.dart';
import 'routes_child.dart';
import 'routes_entry.dart';
import 'routes_guardian.dart';
import 'routes_routine_flow.dart';

/// 연결 암호 넣기 화면 아래에 깔아 둘 화면 — **뒤로가기의 도착지**다.
///
/// 세션이 있으면 역할 선택(잘못 고른 사람이 돌아간다), 없으면 로그인이다. 역할 선택은 세션이 있어야
/// 열리는 화면이라, 세션 없이 깔면 가드가 연결 화면으로 바꿔 스택이 `[연결, 연결]`이 된다 — 뒤로가기가
/// 같은 화면만 다시 보여 주고 빠져나갈 길이 없었다.
String linkEnterBackTarget({required bool hasSession}) =>
    hasSession ? Routes.roleSelect : Routes.login;

/// 연결 암호 넣기 화면으로 보낸다 — 앱을 켰을 때·세션이 끝난 뒤 공통 도착지다.
///
/// go 로 바로 띄우면 스택이 비어 뒤로 갈 수 없으므로 [linkEnterBackTarget] 을 깔고 그 위에 얹는다.
void goToLinkEnter(GoRouter router, {required bool hasSession}) {
  router.go(linkEnterBackTarget(hasSession: hasSession));
  router.push(Routes.linkEnter);
}

/// 초대 링크가 열렸을 때 라우터가 **어디에 머물 것인가**.
///
/// 링크는 화면 경로가 아니다. 주소(`elum://invite?...`)를 그대로 라우트로 풀면 일치하는 화면이
/// 없어 오류 화면이 뜨고, 앱이 막 켜졌다면 로그인·온보딩 상태도 모르는 채 입력 화면을 열게 된다.
/// 그래서 링크는 [InviteInbox](우편함)에 맡기고 라우터는 **자리를 바꾸지 않는다.**
///
/// - 앱이 켜져 있었다면([currentLocation]) 보던 화면 그대로 — 하던 일을 잃지 않는다.
/// - 막 켜졌다면(null) 시작 화면 — 시작 화면이 로그인·역할·온보딩 상태를 보고 갈 곳을 정한다.
///
/// 입력 화면은 우편함을 지켜보던 쪽(`ElumApp`)이 알맞은 자리에서 연다.
@visibleForTesting
String resolveInviteLinkLocation({String? currentLocation}) =>
    (currentLocation == null || currentLocation.isEmpty)
    ? Routes.splash
    : currentLocation;

/// 온보딩 단계 사이의 진행은 각 화면 CTA가 막으므로 여기서 관여하지 않는다.
///
/// 콜백을 넘기지 않으면 가드가 비활성화된다(테스트용).
///
/// [onInviteLink] — 초대 링크(`InviteLink`)가 열렸을 때 불린다. 이룸이 휴대폰에서 열린 링크는
/// 부르지 않고 무시한다 (이룸이 휴대폰은 초대를 받을 수 없다). 코드는 로그에 남기지 않는다.
GoRouter createRouter({
  bool Function()? isOnboardingCompleted,
  bool Function()? hasToken,
  bool Function()? isElumiDevice,
  bool Function()? hasRole,
  bool Function()? requiresGuardianPinSetup,
  void Function(InviteLink link)? onInviteLink,
}) {
  // 리다이렉트가 라우터 자신의 현재 위치를 알아야 한다 — 만들어진 뒤에 채운다.
  late final GoRouter router;
  router = GoRouter(
    initialLocation: Routes.splash,
    redirect: (context, state) {
      // 초대 링크는 다른 가드보다 먼저 본다. 주소가 우리 라우트가 아니라 아래 규칙이 그대로 두면
      // 오류 화면이 된다.
      final link = InviteLink.parse(state.uri);
      if (link != null) {
        if (!(isElumiDevice?.call() ?? false)) onInviteLink?.call(link);
        // 막 켜졌다면 아직 위치가 없어 빈 문자열이다
        return resolveInviteLinkLocation(
          currentLocation: router.routerDelegate.currentConfiguration.uri.toString(),
        );
      }
      return resolveRedirect(
        state.matchedLocation,
        hasSession: hasToken?.call() ?? true,
        onboardingCompleted: isOnboardingCompleted?.call() ?? true,
        skipOnboarding: AppConfig.skipOnboarding,
        isElumiDevice: isElumiDevice?.call() ?? false,
        hasRole: hasRole?.call() ?? true,
        modeSwitchTo: state.uri.queryParameters['to'],
        requiresGuardianPinSetup: requiresGuardianPinSetup?.call() ?? false,
      );
    },
    routes: [
      ...entryRoutes(),
      ...guardianRoutes(),
      ...routineFlowRoutes(),
      ...childRoutes(),
    ],
    // 잘못된 경로로 들어와도 앱이 죽지 않는다 — 발표 중 치명적이다
    errorBuilder: (context, state) =>
        _Placeholder(context.l10n.commonScreenNotFound),
  );
  return router;
}

/// 아직 구현하지 않은 화면. 라우트 구조를 먼저 고정해두기 위한 자리표시자다.
class _Placeholder extends StatelessWidget {
  const _Placeholder(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Text(label, style: Theme.of(context).textTheme.headlineMedium),
      ),
    );
  }
}
