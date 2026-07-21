import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../features/onboarding/presentation/character_screen.dart';
import '../../features/onboarding/presentation/goals_screen.dart';
import '../../features/onboarding/presentation/name_screen.dart';
import '../../features/onboarding/presentation/pin_screen.dart';
import '../../features/onboarding/presentation/splash_screen.dart';

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
/// 온보딩은 앞 단계 입력이 있어야 다음이 의미를 갖는다(제목에 호칭이 들어간다).
/// 각 화면의 CTA가 진행을 막지만, 딥링크로 중간에 들어오는 경우도 있으므로
/// redirect로 한 번 더 거른다.
GoRouter createRouter() {
  return GoRouter(
    initialLocation: Routes.splash,
    routes: [
      GoRoute(
        path: Routes.splash,
        builder: (context, state) => const SplashScreen(),
      ),
      GoRoute(
        path: Routes.onboardingName,
        builder: (context, state) => const NameScreen(),
      ),
      GoRoute(
        path: Routes.onboardingGoals,
        builder: (context, state) => const GoalsScreen(),
      ),
      GoRoute(
        path: Routes.onboardingCharacter,
        builder: (context, state) => const CharacterScreen(),
      ),
      GoRoute(
        path: Routes.onboardingPin,
        builder: (context, state) => const PinScreen(),
      ),
      GoRoute(
        path: Routes.onboardingDone,
        builder: (context, state) => const OnboardingDoneScreen(),
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
