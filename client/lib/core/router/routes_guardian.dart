import 'package:go_router/go_router.dart';

import '../../features/ads/presentation/ad_bottom_strip_slot.dart';
import '../../features/credit/presentation/credit_history_screen.dart';
import '../../features/feedback/presentation/feedback_screen.dart';
import '../../features/guardian/presentation/draft_routines_screen.dart';
import '../../features/guardian/presentation/guardian_home_screen.dart';
import '../../features/guardian/presentation/guardian_my_info_screen.dart';
import '../../features/guardian/presentation/guardian_settings_screen.dart';
import '../../features/guardian/presentation/image_style_settings_screen.dart';
import '../../features/guardian/presentation/navigation/guardian_shell.dart';
import '../../features/guardian/presentation/pin_change_screen.dart';
import '../../features/guardian/presentation/routine_manage_screen.dart';
import '../../features/link/presentation/link_code_screen.dart';
import '../../features/link/presentation/link_enter_screen.dart';
import '../../features/link/presentation/link_status_screen.dart';
import '../../features/notice/presentation/guardian_notice_launcher.dart';
import '../../features/notification/presentation/notification_settings_screen.dart';
import '../../features/notification/presentation/notifications_screen.dart';
import '../../features/profile/presentation/elumi_info_screen.dart';
import '../../features/profile/presentation/guardians_screen.dart';
import '../../features/profile/presentation/invite_code_screen.dart';
import '../../features/profile/presentation/profile_switch_screen.dart';
import '../../features/talk/presentation/talk_blocked_guardians_screen.dart';
import '../../features/talk/presentation/talk_my_posts_screen.dart';
import '../../features/talk/presentation/talk_detail_screen.dart';
import '../../features/talk/presentation/talk_feed_screen.dart';
import '../../features/talk/presentation/talk_share_screen.dart';
import '../config/ad_ids.dart';
import '../layout/adaptive_page_frame.dart';
import '../layout/screen_layout_kind.dart';
import 'app_transitions.dart';
import 'routes.dart';

/// 보호자 화면과 설정·연결·사람 관리.
List<RouteBase> guardianRoutes() => [
  // --- 보호자 모드: 칸 4개 (홈 · 일과관리 · 이야기 · 내정보) ---
  // 가지 순서 = GuardianTab 순서. 칸을 더하면 GuardianTab 과 여기 가지를 함께 늘린다.
  // 칸 안 화면만 가지에 두고, 설정 하위 화면·일과 만들기처럼 바를 덮는 화면은 바깥(루트)에 둔다.
  StatefulShellRoute.indexedStack(
    builder: (context, state, navigationShell) => GuardianShell(
      navigationShell: navigationShell,
      adStrip: const AdBottomStripSlot(placement: AdPlacement.bannerHome),
    ),
    branches: [
      StatefulShellBranch(
        routes: [
          // 온보딩 완료 → 홈은 맥락 전환이라 fade (motion.md "시작 화면 → 홈" 준용).
          GoRoute(
            path: Routes.guardian,
            // 공지 팝업은 **이 자리에서만** 뜬다. 이룸이 화면·일과 만들기에는
            // 감싸지 않는다 — 이룸이 화면은 한 화면에 행동 하나다.
            // 홈이 태블릿 구성(가운데 열·가로 두 칸)을 직접 정한다
            pageBuilder: (context, state) => fadePage(
              state,
              const GuardianNoticeLauncher(child: GuardianHomeScreen()),
              layoutKind: ScreenLayoutKind.adaptive,
            ),
          ),
        ],
      ),
      StatefulShellBranch(
        routes: [
          GoRoute(
            path: Routes.guardianManage,
            pageBuilder: (context, state) => fadePage(
              state,
              const RoutineManageScreen(),
              // 아이콘 격자라 넓은 창에서는 열을 늘려 폭을 다 쓴다 (가운데 열에 가두면 오른쪽이 빈다)
              layoutKind: ScreenLayoutKind.adaptive,
            ),
          ),
        ],
      ),
      StatefulShellBranch(
        routes: [
          GoRoute(
            path: Routes.guardianTalk,
            pageBuilder: (context, state) => fadePage(
              state,
              const TalkFeedScreen(),
              layoutKind: ScreenLayoutKind.contentColumn,
            ),
          ),
        ],
      ),
      StatefulShellBranch(
        routes: [
          GoRoute(
            path: Routes.guardianMyInfo,
            pageBuilder: (context, state) => fadePage(
              state,
              const GuardianMyInfoScreen(),
              layoutKind: ScreenLayoutKind.contentColumn,
            ),
          ),
        ],
      ),
    ],
  ),
  // 이야기 글 상세·올리기·숨긴 보호자: 하단 바를 덮는 화면이라 셸 밖에 둔다
  GoRoute(
    path: Routes.guardianTalkPost,
    pageBuilder: (context, state) => slidePage(
      state,
      TalkDetailScreen(postId: state.pathParameters['postId'] ?? ''),
      layoutKind: ScreenLayoutKind.contentColumn,
    ),
  ),
  // 이야기 올리기: extra 는 입구가 정한 일과 id (없으면 일과 고르기부터)
  GoRoute(
    path: Routes.guardianTalkShare,
    pageBuilder: (context, state) => slidePage(
      state,
      TalkShareScreen(
        initialRoutineId: state.extra is String ? state.extra as String : null,
      ),
      layoutKind: ScreenLayoutKind.contentColumn,
    ),
  ),
  GoRoute(
    path: Routes.guardianTalkBlocks,
    pageBuilder: (context, state) =>
        slidePage(state, const TalkBlockedGuardiansScreen()),
  ),
  GoRoute(
    path: Routes.guardianTalkMine,
    pageBuilder: (context, state) => slidePage(state, const TalkMyPostsScreen()),
  ),
  // 설정은 내정보 칸 위에 열린다 (하단 바를 덮고 뒤로가기가 있다)
  GoRoute(
    path: Routes.guardianSettings,
    pageBuilder: (context, state) =>
        slidePage(state, const GuardianSettingsScreen()),
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
    pageBuilder: (context, state) => slidePage(state, const LinkEnterScreen()),
  ),
  GoRoute(
    path: Routes.guardianDrafts,
    builder: (context, state) => const AdaptivePageFrame(
      kind: ScreenLayoutKind.phoneColumn,
      child: DraftRoutinesScreen(),
    ),
  ),
  GoRoute(
    path: Routes.guardianImageStyle,
    pageBuilder: (context, state) =>
        slidePage(state, const ImageStyleSettingsScreen()),
  ),
  GoRoute(
    path: Routes.guardianFeedback,
    pageBuilder: (context, state) => slidePage(state, const FeedbackScreen()),
  ),
  GoRoute(
    path: Routes.guardianNotifications,
    pageBuilder: (context, state) => slidePage(
      state,
      NotificationsScreen(
        isNoticeTabInitiallySelected:
            state.uri.queryParameters[Routes.notificationsTabQuery] ==
            Routes.notificationsNoticeTabValue,
      ),
    ),
  ),
  GoRoute(
    path: Routes.guardianNotificationSettings,
    pageBuilder: (context, state) =>
        slidePage(state, const NotificationSettingsScreen()),
  ),
  GoRoute(
    path: Routes.guardianCreditHistory,
    pageBuilder: (context, state) =>
        slidePage(state, const CreditHistoryScreen()),
  ),
  // 다중 보호자 — 시안이 없는 임시 화면들이다.
  GoRoute(
    path: Routes.guardianPeople,
    pageBuilder: (context, state) => slidePage(state, const GuardiansScreen()),
  ),
  GoRoute(
    path: Routes.guardianInvite,
    pageBuilder: (context, state) => slidePage(state, const InviteCodeScreen()),
  ),
  GoRoute(
    path: Routes.guardianProfileSwitch,
    pageBuilder: (context, state) =>
        slidePage(state, const ProfileSwitchScreen()),
  ),
  GoRoute(
    path: Routes.guardianElumiInfo,
    pageBuilder: (context, state) => slidePage(
      state,
      ElumiInfoScreen(
        profileId:
            state.uri.queryParameters[Routes.elumiInfoProfileIdQuery] ?? '',
      ),
      layoutKind: ScreenLayoutKind.contentColumn,
    ),
  ),
  GoRoute(
    path: Routes.guardianLinkStatus,
    pageBuilder: (context, state) => slidePage(state, const LinkStatusScreen()),
  ),
  GoRoute(
    path: Routes.guardianPinChange,
    pageBuilder: (context, state) => slidePage(
      state,
      // 암호가 없는 휴대폰이 보호자 화면에 들어올 때 거치는 길이다
      PinChangeScreen(createOnly: state.uri.queryParameters['from'] == 'login'),
    ),
  ),
];
