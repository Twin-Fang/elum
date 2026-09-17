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
import '../../features/auth/presentation/consent_screen.dart';
import '../../features/auth/presentation/login_screen.dart';
import '../../features/onboarding/presentation/splash_screen.dart';
import 'app_transitions.dart';

/// 앱 라우트 경로 상수. 문자열을 화면마다 반복해 적지 않는다.
abstract final class Routes {
  static const splash = '/';

  /// 온보딩 맨 앞. 계정이 먼저 생기고 그 안에 당사자 프로필을 만든다.
  static const login = '/login';

  /// 약관 동의. 로그인 직후, 아이 정보를 받기 전에 선다.
  /// 동의 없이는 서비스를 쓸 수 없다.
  static const consent = '/consent';

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

/// 경로 가드. **순수 함수로 떼어 두었다** — 라우터를 위젯 트리에 올리지 않고도
/// 검증할 수 있어야 하기 때문이다.
///
/// 실제로 이 판단을 `createRouter` 안에 두었을 때, 가입 절차(약관 동의 → 아이 정보)를
/// "온보딩 미완료면 이름 화면으로" 규칙에 함께 넣는 사고가 났다. 절차를 밟는 도중에는
/// 온보딩이 항상 미완료라 **어느 단계로 가든 이름 화면으로 되돌려졌다.**
/// 동의 화면이 통째로 건너뛰어졌고 이름 입력 후 다음으로도 넘어가지 못했다.
///
/// @return 이동시킬 경로. null이면 그대로 둔다.
@visibleForTesting
String? resolveRedirect(
  String path, {
  required bool hasSession,
  required bool onboardingCompleted,
  required bool skipOnboarding,
}) {
  // 가입 절차도 로그인이 있어야 한다. 계정이 없으면 동의를 기록할 곳도,
  // 아이 정보를 저장할 곳도 없다.
  final isSignUpFlow =
      path.startsWith(Routes.consent) || path.startsWith('/onboarding');
  final needsSession = isSignUpFlow ||
      path.startsWith(Routes.guardian) ||
      path.startsWith(Routes.child);
  if (!needsSession) return null;

  // 세션이 없으면 아무것도 조회할 수 없다. 로그인부터 다시 시작한다.
  if (!hasSession) return Routes.login;

  // 가입 절차 안에서는 단계 이동을 막지 않는다.
  if (isSignUpFlow) return null;

  // devFlag: 온보딩 건너뛰기 (시연용)
  if (skipOnboarding) return null;

  // 보호자·아이 화면은 온보딩을 마쳐야 들어갈 수 있다.
  return onboardingCompleted ? null : Routes.onboardingName;
}

/// 온보딩 단계 사이의 진행은 각 화면 CTA가 막으므로 여기서 관여하지 않는다.
///
/// 콜백을 넘기지 않으면 가드가 비활성화된다(테스트용).
GoRouter createRouter({
  bool Function()? isOnboardingCompleted,
  bool Function()? hasToken,
}) {
  return GoRouter(
    initialLocation: Routes.splash,
    redirect: (context, state) => resolveRedirect(
      state.matchedLocation,
      hasSession: hasToken?.call() ?? true,
      onboardingCompleted: isOnboardingCompleted?.call() ?? true,
      skipOnboarding: AppConfig.skipOnboarding,
    ),
    routes: [
      GoRoute(
        path: Routes.splash,
        builder: (context, state) => const SplashScreen(),
      ),

      // --- 로그인 ---
      // 온보딩 앞에 서므로 같은 수평 슬라이드를 쓴다.
      GoRoute(
        path: Routes.login,
        pageBuilder: (context, state) => slidePage(state, const LoginScreen()),
      ),

      GoRoute(
        path: Routes.consent,
        pageBuilder: (context, state) => slidePage(state, const ConsentScreen()),
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
