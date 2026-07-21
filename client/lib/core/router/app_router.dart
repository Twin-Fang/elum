import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../features/guardian/presentation/card_review_screen.dart';
import '../../features/guardian/presentation/dlp_screen.dart';
import '../../features/guardian/presentation/guardian_home_screen.dart';
import '../../features/guardian/presentation/question_screen.dart';
import '../../features/guardian/presentation/routine_input_screen.dart';
import '../../features/onboarding/presentation/character_screen.dart';
import '../../features/onboarding/presentation/goals_screen.dart';
import '../../features/onboarding/presentation/name_screen.dart';
import '../../features/onboarding/presentation/pin_screen.dart';
import '../../features/onboarding/presentation/setup_done_screen.dart';
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
  static const routineInput = '/guardian/routine/input';
  static const routineMasking = '/guardian/routine/masking';
  static const routineQuestion = '/guardian/routine/question';
  static const routineReview = '/guardian/routine/review';

  static const child = '/child';
}

/// go_router 설정.
///
/// **redirect 규칙**: 토큰이 없으면 보호자·아동 화면에 들어갈 수 없다.
/// 토큰이 인증의 유일한 증거이므로 온보딩 완료 플래그만으로는 부족하다 —
/// 회원삭제로 토큰이 날아간 상태를 잡지 못한다. (이슈 #19)
///
/// 보호 화면에 토큰 없이 접근하면 **시작 화면**으로 되돌린다.
/// 온보딩 단계 사이의 진행은 각 화면 CTA가 막으므로 여기서 관여하지 않는다.
///
/// 콜백을 넘기지 않으면 가드가 비활성화된다(테스트용).
GoRouter createRouter({
  bool Function()? isOnboardingCompleted,
  bool Function()? hasToken,
}) {
  return GoRouter(
    initialLocation: Routes.splash,
    redirect: (context, state) {
      final path = state.matchedLocation;
      final isProtected =
          path.startsWith(Routes.guardian) || path.startsWith(Routes.child);
      if (!isProtected) return null;

      // 토큰이 없으면 아무것도 조회할 수 없다. 시작 화면부터 다시 시작한다.
      if (hasToken != null && !hasToken()) return Routes.splash;

      final isDone = isOnboardingCompleted?.call() ?? true;
      return isDone ? null : Routes.onboardingName;
    },
    routes: [
      GoRoute(
        path: Routes.splash,
        builder: (context, state) => const SplashScreen(),
      ),

      // --- 온보딩 ---
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
        builder: (context, state) => const SetupDoneScreen(),
      ),

      // --- 보호자 모드 ---
      GoRoute(
        path: Routes.guardian,
        builder: (context, state) => const GuardianHomeScreen(),
      ),
      GoRoute(
        path: Routes.routineInput,
        builder: (context, state) => const RoutineInputScreen(),
      ),
      GoRoute(
        path: Routes.routineMasking,
        builder: (context, state) => const DlpScreen(),
      ),
      GoRoute(
        path: Routes.routineQuestion,
        builder: (context, state) => const QuestionScreen(),
      ),
      GoRoute(
        path: Routes.routineReview,
        builder: (context, state) => const CardReviewScreen(),
      ),

      // --- 아동 모드 ---
      GoRoute(
        path: Routes.child,
        builder: (context, state) => const _Placeholder('아동 모드'),
      ),
    ],
    // 잘못된 경로로 들어와도 앱이 죽지 않는다 — 발표 중 치명적이다
    errorBuilder: (context, state) => const _Placeholder('화면을 찾을 수 없어요'),
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
