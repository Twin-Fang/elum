import 'package:go_router/go_router.dart';

import '../../features/ads/presentation/ad_bottom_strip_slot.dart';
import '../../features/guardian/presentation/guardian_home_screen.dart';
import '../../features/guardian/presentation/guardian_my_info_screen.dart';
import '../../features/guardian/presentation/navigation/guardian_shell.dart';
import '../../features/guardian/presentation/card_export/card_export_screen.dart';
import '../../features/expert_routine/presentation/expert_routine_detail_screen.dart';
import '../../features/expert_routine/presentation/expert_routine_list_screen.dart';
import '../../features/guardian/presentation/routine_manage_screen.dart';
import '../../features/notice/presentation/guardian_notice_launcher.dart';
import '../../features/talk/presentation/talk_detail_screen.dart';
import '../../features/talk/presentation/talk_feed_screen.dart';
import '../../features/talk/presentation/talk_link_share_screen.dart';
import '../../features/talk/presentation/talk_share_screen.dart';
import '../../shared/models/routine.dart';
import '../config/ad_ids.dart';
import '../layout/screen_layout_kind.dart';
import 'app_transitions.dart';
import 'routes.dart';

/// 보호자 화면: 칸 4개(셸) + 칸 위에 덮는 이야기·전문가 일과·인쇄 화면 (설정·연결·사람 관리는 routes_guardian_settings.dart)
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
  // 링크로 보내기: extra 가 없으면 빈 id 로 열려 미리보기 실패 화면(다시 하기 + 에러 코드)이 뜬다
  GoRoute(
    path: Routes.guardianTalkLinkShare,
    pageBuilder: (context, state) {
      final args = state.extra is TalkLinkShareRouteArgs
          ? state.extra as TalkLinkShareRouteArgs
          : null;
      return slidePage(
        state,
        TalkLinkShareScreen(
          routineId: args?.routineId ?? '',
          hasActiveLink: args?.hasActiveLink ?? false,
        ),
        layoutKind: ScreenLayoutKind.contentColumn,
      );
    },
  ),
  // 전문가 일과 목록·미리 보기: 하단 바를 덮는 화면
  GoRoute(
    path: Routes.guardianExpertRoutines,
    pageBuilder: (context, state) => slidePage(
      state,
      const ExpertRoutineListScreen(),
      layoutKind: ScreenLayoutKind.contentColumn,
    ),
  ),
  GoRoute(
    path: Routes.guardianExpertRoutine,
    pageBuilder: (context, state) => slidePage(
      state,
      ExpertRoutineDetailScreen(
        expertRoutineId: state.pathParameters['expertRoutineId'] ?? '',
      ),
      layoutKind: ScreenLayoutKind.contentColumn,
    ),
  ),
  // 인쇄용으로 받기: extra 가 일과가 아니면 카드 없는 일과 화면(안내)이 뜬다
  GoRoute(
    path: Routes.guardianCardExport,
    pageBuilder: (context, state) => slidePage(
      state,
      CardExportScreen(
        routine: state.extra is Routine ? state.extra as Routine : const Routine(id: ''),
      ),
      layoutKind: ScreenLayoutKind.contentColumn,
    ),
  ),
];
