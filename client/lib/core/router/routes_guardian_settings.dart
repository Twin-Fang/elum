import 'package:go_router/go_router.dart';

import '../../features/auth/presentation/consent_document_list_screen.dart';
import '../../features/child/presentation/mode_switch_screen.dart';
import '../../features/credit/presentation/credit_history_screen.dart';
import '../../features/feedback/presentation/feedback_screen.dart';
import '../../features/guardian/presentation/draft_routines_screen.dart';
import '../../features/guardian/presentation/guardian_settings_screen.dart';
import '../../features/guardian/presentation/image_style_settings_screen.dart';
import '../../features/guardian/presentation/routine_memory_screen.dart';
import '../../features/guardian/presentation/pin_change_screen.dart';
import '../../features/guardian/presentation/weekly_report/weekly_report_screen.dart';
import '../../features/guardian/presentation/weekly_plan_screen.dart';
import '../../features/license/presentation/open_source_licenses_screen.dart';
import '../../features/link/presentation/link_code_screen.dart';
import '../../features/link/presentation/link_enter_screen.dart';
import '../../features/link/presentation/link_status_screen.dart';
import '../../features/notification/presentation/notification_settings_screen.dart';
import '../../features/notification/presentation/notifications_screen.dart';
import '../../features/profile/presentation/elumi_info_screen.dart';
import '../../features/profile/presentation/guardians_screen.dart';
import '../../features/profile/presentation/invite_code_screen.dart';
import '../../features/profile/presentation/profile_switch_screen.dart';
import '../../features/talk/presentation/talk_blocked_guardians_screen.dart';
import '../../features/talk/presentation/talk_my_posts_screen.dart';
import '../layout/adaptive_page_frame.dart';
import '../layout/screen_layout_kind.dart';
import 'app_transitions.dart';
import 'routes.dart';

/// 보호자 설정 하위 화면: 결제 확인·약관·리포트·계획·알림·크레딧·연결·사람 관리 (하단 바를 덮음)
List<RouteBase> guardianSettingsRoutes() => [
  // 결제 직전 보호자 확인: 화면 전환 암호 화면을 그대로 쓰고 맞으면 true 로 닫힌다
  GoRoute(
    path: Routes.guardianPlanPin,
    builder: (context, state) => const AdaptivePageFrame(
      kind: ScreenLayoutKind.phoneColumn,
      child: ModeSwitchScreen(target: ModeSwitchTarget.purchase),
    ),
  ),
  GoRoute(
    path: Routes.guardianTerms,
    pageBuilder: (context, state) =>
        slidePage(state, const ConsentDocumentListScreen()),
  ),
  GoRoute(
    path: Routes.guardianWeeklyReport,
    pageBuilder: (context, state) => slidePage(
      state,
      const WeeklyReportScreen(),
      layoutKind: ScreenLayoutKind.contentColumn,
    ),
  ),
  // 주간 계획 (#782): 요일마다 반복 일과
  GoRoute(
    path: Routes.guardianWeeklyPlan,
    pageBuilder: (context, state) => slidePage(
      state,
      const WeeklyPlanScreen(),
      layoutKind: ScreenLayoutKind.contentColumn,
    ),
  ),
  GoRoute(
    path: Routes.guardianLicenses,
    pageBuilder: (context, state) =>
        slidePage(state, const OpenSourceLicensesScreen()),
  ),
  GoRoute(
    path: Routes.guardianTalkBlocks,
    pageBuilder: (context, state) =>
        slidePage(state, const TalkBlockedGuardiansScreen()),
  ),
  GoRoute(
    path: Routes.guardianTalkMine,
    pageBuilder: (context, state) =>
        slidePage(state, const TalkMyPostsScreen()),
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
    path: Routes.guardianRoutineMemory,
    pageBuilder: (context, state) =>
        slidePage(state, const RoutineMemoryScreen()),
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
