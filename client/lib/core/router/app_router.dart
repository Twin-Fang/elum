import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// 앱 라우트 경로 상수. 문자열을 화면마다 반복해 적지 않는다.
abstract final class Routes {
  static const splash = '/';
  static const onboardingName = '/onboarding/name';
  static const onboardingGoals = '/onboarding/goals';
  static const onboardingCharacter = '/onboarding/character';
  static const onboardingPin = '/onboarding/pin';
  static const onboardingDone = '/onboarding/done';
  static const guardian = '/guardian';
  static const child = '/child';
}

/// go_router 설정.
///
/// 화면 구현은 개별 작업으로 진행하므로, 지금은 각 라우트가 자리표시자를 띄운다.
/// 라우트 구조를 먼저 고정해두면 화면을 붙일 때 경로가 흔들리지 않는다.
final appRouter = GoRouter(
  initialLocation: Routes.splash,
  routes: [
    GoRoute(
      path: Routes.splash,
      builder: (context, state) => const _Placeholder('시작'),
    ),
    GoRoute(
      path: Routes.onboardingName,
      builder: (context, state) => const _Placeholder('온보딩 · 이름'),
    ),
    GoRoute(
      path: Routes.onboardingGoals,
      builder: (context, state) => const _Placeholder('온보딩 · 도움 목표'),
    ),
    GoRoute(
      path: Routes.onboardingCharacter,
      builder: (context, state) => const _Placeholder('온보딩 · 캐릭터'),
    ),
    GoRoute(
      path: Routes.onboardingPin,
      builder: (context, state) => const _Placeholder('온보딩 · 비밀암호'),
    ),
    GoRoute(
      path: Routes.onboardingDone,
      builder: (context, state) => const _Placeholder('온보딩 · 완료'),
    ),
    GoRoute(
      path: Routes.guardian,
      builder: (context, state) => const _Placeholder('보호자 모드'),
    ),
    GoRoute(
      path: Routes.child,
      builder: (context, state) => const _Placeholder('아동 모드'),
    ),
  ],
);

/// 화면 구현 전까지 라우트가 살아있는지 확인하는 용도.
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
