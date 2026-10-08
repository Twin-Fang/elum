import 'package:go_router/go_router.dart';

import '../../features/feedback/presentation/feedback_screen.dart';
import '../../features/guardian/presentation/draft_routines_screen.dart';
import '../../features/guardian/presentation/guardian_home_screen.dart';
import '../../features/guardian/presentation/guardian_settings_screen.dart';
import '../../features/guardian/presentation/image_style_settings_screen.dart';
import '../../features/guardian/presentation/pin_change_screen.dart';
import '../../features/link/presentation/link_code_screen.dart';
import '../../features/link/presentation/link_enter_screen.dart';
import '../../features/link/presentation/link_status_screen.dart';
import '../../features/notice/presentation/guardian_notice_launcher.dart';
import '../../features/profile/presentation/guardians_screen.dart';
import '../../features/profile/presentation/invite_code_screen.dart';
import '../../features/profile/presentation/profile_switch_screen.dart';
import 'app_transitions.dart';
import 'routes.dart';

/// 보호자 화면과 설정·연결·사람 관리.
List<RouteBase> guardianRoutes() => [

  // --- 보호자 모드 ---
  // 온보딩 완료 → 홈은 맥락 전환이라 fade (motion.md "시작 화면 → 홈" 준용).
  // 다른 경로에서 홈으로 올 때도 fade가 걸리는데, 즉시 교체보다 나으므로 허용.
  GoRoute(
    path: Routes.guardian,
    // 공지 팝업은 **이 자리에서만** 뜬다. 이룸이 화면·일과 만들기에는
    // 감싸지 않는다 — 이룸이 화면은 한 화면에 행동 하나다.
    pageBuilder: (context, state) => fadePage(
      state,
      const GuardianNoticeLauncher(child: GuardianHomeScreen()),
    ),
  ),
  GoRoute(
    path: Routes.linkCode,
    pageBuilder: (context, state) => slidePage(
      state,
      LinkCodeScreen(
        // 온보딩에서 들어왔을 때만 `나중에 할게요`를 보여준다.
        fromOnboarding: state.uri.queryParameters['from'] == 'onboarding',
      ),
    ),
  ),
  GoRoute(
    path: Routes.linkEnter,
    pageBuilder: (context, state) =>
        slidePage(state, const LinkEnterScreen()),
  ),
  GoRoute(
    path: Routes.guardianSettings,
    pageBuilder: (context, state) =>
        slidePage(state, const GuardianSettingsScreen()),
  ),
  GoRoute(
    path: Routes.guardianDrafts,
    builder: (context, state) => const DraftRoutinesScreen(),
  ),
  GoRoute(
    path: Routes.guardianImageStyle,
    pageBuilder: (context, state) =>
        slidePage(state, const ImageStyleSettingsScreen()),
  ),
  GoRoute(
    path: Routes.guardianFeedback,
    pageBuilder: (context, state) =>
        slidePage(state, const FeedbackScreen()),
  ),
  // 다중 보호자 — 시안이 없는 임시 화면들이다.
  GoRoute(
    path: Routes.guardianPeople,
    pageBuilder: (context, state) =>
        slidePage(state, const GuardiansScreen()),
  ),
  GoRoute(
    path: Routes.guardianInvite,
    pageBuilder: (context, state) =>
        slidePage(state, const InviteCodeScreen()),
  ),
  GoRoute(
    path: Routes.guardianProfileSwitch,
    pageBuilder: (context, state) =>
        slidePage(state, const ProfileSwitchScreen()),
  ),
  GoRoute(
    path: Routes.guardianLinkStatus,
    pageBuilder: (context, state) =>
        slidePage(state, const LinkStatusScreen()),
  ),
  GoRoute(
    path: Routes.guardianPinChange,
    pageBuilder: (context, state) => slidePage(
      state,
      // 암호가 없는 휴대폰이 보호자 화면에 들어올 때 거치는 길이다
      PinChangeScreen(
        createOnly:
            state.uri.queryParameters['from'] == 'login',
      ),
    ),
  ),
];
