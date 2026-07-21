import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/config/app_config.dart';
import '../../features/guardian/presentation/card_review_screen.dart';
import '../../features/guardian/presentation/guardian_home_screen.dart';
import '../../features/child/presentation/child_home_screen.dart';
import '../../features/child/presentation/child_routine_detail_screen.dart';
import '../../features/child/presentation/child_stars_screen.dart';
import '../../features/child/presentation/mode_switch_screen.dart';
import '../../features/child/presentation/reward_screen.dart';
import '../../shared/models/routine.dart';
import '../../features/guardian/domain/routine_stage.dart';
import '../../features/guardian/presentation/routine_loading_screen.dart';
import '../../features/guardian/presentation/question_screen.dart';
import '../../features/guardian/presentation/routine_input_screen.dart';
import '../../features/onboarding/presentation/card_completion_screen.dart';
import '../../features/onboarding/presentation/character_screen.dart';
import '../../features/onboarding/presentation/goals_screen.dart';
import '../../features/onboarding/presentation/name_screen.dart';
import '../../features/onboarding/presentation/pin_screen.dart';
import '../../features/onboarding/presentation/splash_screen.dart';
import 'app_transitions.dart';

/// 앱 라우트 경로 상수. 문자열을 화면마다 반복해 적지 않는다.
abstract final class Routes {
  static const splash = '/';

  static const onboardingName = '/onboarding/name';
  static const onboardingGoals = '/onboarding/goals';
  static const onboardingCharacter = '/onboarding/character';
  static const onboardingPin = '/onboarding/pin';
  static const cardCompletion = '/onboarding/card-completion';

  static const guardian = '/guardian';
  static const routineInput = '/guardian/routine/input';
  /// DLP 마스킹 + 추가 질문 준비 로딩 (Figma 262:4569).
  /// 경로 이름은 DLP 시절 것을 유지한다 — 마스킹이 이 단계에서 일어나므로
  /// 의미가 어긋나지 않는다.
  static const routineMasking = '/guardian/routine/masking';
  static const routineQuestion = '/guardian/routine/question';

  /// 행동카드 생성 로딩 (Figma 262:4703).
  /// [routineMasking]과 화면은 같고 문구·진행률·다음 목적지가 다르다.
  static const routineGenerating = '/guardian/routine/generating';
  static const routineReview = '/guardian/routine/review';

  static const child = '/child';

  /// 일과 상세 — 카드 페이저 (Figma 309:3548). `extra`로 Routine을 넘긴다.
  static const childRoutineDetail = '/child/routine';

  /// 누적 별 (Figma 364:8219)
  static const childStars = '/child/stars';

  /// 아이 보상 (Figma 309:4055 등 3종 랜덤)
  static const childReward = '/child/reward';

  /// 모드 전환 PIN. `?to=child|guardian`으로 방향을 준다.
  static const modeSwitch = '/mode-switch';
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

      // devFlag: 온보딩 건너뛰기 (시연용)
      if (AppConfig.skipOnboarding) return null;

      final isDone = isOnboardingCompleted?.call() ?? true;
      return isDone ? null : Routes.onboardingName;
    },
    routes: [
      GoRoute(
        path: Routes.splash,
        builder: (context, state) => const SplashScreen(),
      ),

      // --- 온보딩 ---
      // 단계 진행은 수평 슬라이드 — 즉시 교체는 motion.md 금지 사항이다.
      GoRoute(
        path: Routes.onboardingName,
        pageBuilder: (context, state) => slidePage(state, const NameScreen()),
      ),
      GoRoute(
        path: Routes.onboardingGoals,
        pageBuilder: (context, state) => slidePage(state, const GoalsScreen()),
      ),
      GoRoute(
        path: Routes.onboardingCharacter,
        pageBuilder: (context, state) =>
            slidePage(state, const CharacterScreen()),
      ),
      GoRoute(
        path: Routes.onboardingPin,
        pageBuilder: (context, state) => slidePage(state, const PinScreen()),
      ),
      GoRoute(
        path: Routes.cardCompletion,
        builder: (context, state) => const CardCompletionScreen(),
      ),

      // --- 보호자 모드 ---
      // 온보딩 완료 → 홈은 맥락 전환이라 fade (motion.md "시작 화면 → 홈" 준용).
      // 다른 경로에서 홈으로 올 때도 fade가 걸리는데, 즉시 교체보다 나으므로 허용.
      GoRoute(
        path: Routes.guardian,
        pageBuilder: (context, state) =>
            fadePage(state, const GuardianHomeScreen()),
      ),
      GoRoute(
        path: Routes.routineInput,
        builder: (context, state) => const RoutineInputScreen(),
      ),
      GoRoute(
        path: Routes.routineMasking,
        builder: (context, state) =>
            const RoutineLoadingScreen(kind: RoutineLoadingKind.prepare),
      ),
      GoRoute(
        path: Routes.routineQuestion,
        builder: (context, state) => const QuestionScreen(),
      ),
      GoRoute(
        path: Routes.routineGenerating,
        builder: (context, state) =>
            const RoutineLoadingScreen(kind: RoutineLoadingKind.generate),
      ),
      GoRoute(
        path: Routes.routineReview,
        builder: (context, state) => const CardReviewScreen(),
      ),

      // --- 아동 모드 ---
      GoRoute(
        path: Routes.child,
        builder: (context, state) => const ChildHomeScreen(),
      ),
      GoRoute(
        path: Routes.childRoutineDetail,
        builder: (context, state) {
          // extra 없이 들어오면(딥링크 등) 보여줄 일과가 없다 — 홈으로 돌린다.
          final routine = state.extra;
          if (routine is! Routine) return const ChildHomeScreen();
          return ChildRoutineDetailScreen(routine: routine);
        },
      ),
      // 어두운 밤하늘 배경이라 옆에서 밀려드는 슬라이드가 부자연스럽다.
      // fade로 쓱 나타나게 한다 (이슈 #107).
      GoRoute(
        path: Routes.childStars,
        pageBuilder: (context, state) =>
            fadePage(state, const ChildStarsScreen()),
      ),
      GoRoute(
        path: Routes.childReward,
        pageBuilder: (context, state) =>
            fadePage(state, const RewardScreen()),
      ),
      GoRoute(
        path: Routes.modeSwitch,
        builder: (context, state) => ModeSwitchScreen(
          target: ModeSwitchTarget.fromName(state.uri.queryParameters['to']),
        ),
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
