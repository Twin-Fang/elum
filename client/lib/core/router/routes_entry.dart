import 'package:go_router/go_router.dart';

import '../../features/auth/presentation/consent_screen.dart';
import '../../features/auth/presentation/login_screen.dart';
import '../../features/auth/presentation/role_select_screen.dart';
import '../../features/onboarding/presentation/card_completion_screen.dart';
import '../../features/onboarding/presentation/character_screen.dart';
import '../../features/onboarding/presentation/goals_screen.dart';
import '../../features/onboarding/presentation/image_style_screen.dart';
import '../../features/onboarding/presentation/name_screen.dart';
import '../../features/onboarding/presentation/pin_screen.dart';
import '../../features/onboarding/presentation/splash_screen.dart';
import '../../features/profile/presentation/invite_enter_screen.dart';
import 'app_transitions.dart';
import 'routes.dart';

/// 시작·로그인·동의·역할 선택·온보딩.
List<RouteBase> entryRoutes() => [
  GoRoute(
    path: Routes.splash,
    builder: (context, state) => const SplashScreen(),
  ),

  // --- 로그인 ---
  // **fade를 쓴다. 슬라이드를 쓰면 글자가 두 번 보인다** (이슈 #207).
  //
  // 시작 화면과 로그인 화면은 같은 그림([SplashScene])을 그린다. 수평
  // 슬라이드는 나가는 화면과 들어오는 화면을 가로로 어긋나게 겹치므로,
  // 그림이 같으면 `차근차근 함께해요`·로고·병아리가 통째로 이중으로 찍힌다.
  // fade는 같은 그림끼리 겹쳐도 차이가 보이지 않아, 버튼만 떠오르는 것처럼
  // 읽힌다 — `시작하기`를 없애 두 화면을 하나로 만든 의도와 맞는다.
  GoRoute(
    path: Routes.login,
    pageBuilder: (context, state) => fadePage(state, const LoginScreen()),
  ),

  GoRoute(
    path: Routes.consent,
    pageBuilder: (context, state) =>
        slidePage(state, const ConsentScreen()),
  ),
  GoRoute(
    path: Routes.roleSelect,
    pageBuilder: (context, state) =>
        slidePage(state, const RoleSelectScreen()),
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
  // 초대 코드 넣기 — 새로 가입한 보호자가 이룸이 등록 대신 들어온다 (#362 · E6).
  GoRoute(
    path: Routes.inviteEnter,
    pageBuilder: (context, state) =>
        slidePage(state, const InviteEnterScreen()),
  ),
  GoRoute(
    path: Routes.onboardingImageStyle,
    pageBuilder: (context, state) =>
        slidePage(state, const ImageStyleScreen()),
  ),
  GoRoute(
    path: Routes.onboardingPin,
    pageBuilder: (context, state) => slidePage(state, const PinScreen()),
  ),
  GoRoute(
    path: Routes.cardCompletion,
    builder: (context, state) => const CardCompletionScreen(),
  ),
];
