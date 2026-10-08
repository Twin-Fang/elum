import 'package:go_router/go_router.dart';

import '../../features/child/presentation/child_home_screen.dart';
import '../../features/child/presentation/child_routine_detail_screen.dart';
import '../../features/child/presentation/child_stars_screen.dart';
import '../../features/child/presentation/mode_switch_screen.dart';
import '../../features/child/presentation/reward_screen.dart';
import '../../features/child/presentation/routine_done_screen.dart';
import '../../features/link/presentation/elumi_settings_screen.dart';
import '../../shared/models/routine.dart';
import 'app_transitions.dart';
import 'routes.dart';

/// 이룸이 화면과 화면 전환.
List<RouteBase> childRoutes() => [

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
  // fade로 쓱 나타나게 한다.
  GoRoute(
    path: Routes.childSettings,
    pageBuilder: (context, state) =>
        slidePage(state, const ElumiSettingsScreen()),
  ),
  GoRoute(
    path: Routes.childStars,
    pageBuilder: (context, state) =>
        fadePage(state, const ChildStarsScreen()),
  ),
  GoRoute(
    path: Routes.childReward,
    // 보상은 `extra`로 온다. 개발자 도구로 직접 들어오면 null이라
    // 별 연출만 돈다 — 그 자체가 보상 없이 끝낸 모습이라 맞다.
    pageBuilder: (context, state) => fadePage(
      state,
      RewardScreen(
        reward: state.extra is ({String emoji, String text})
            ? state.extra! as ({String emoji, String text})
            : null,
      ),
    ),
  ),
  GoRoute(
    path: Routes.childRoutineDone,
    // 보상은 `extra`로 온다. 없으면(개발자 도구로 직접 들어온 경우 포함) 칩 없이 그린다.
    pageBuilder: (context, state) => fadePage(
      state,
      RoutineDoneScreen(
        reward: state.extra is ({String emoji, String text})
            ? state.extra! as ({String emoji, String text})
            : null,
      ),
    ),
  ),
  GoRoute(
    path: Routes.modeSwitch,
    builder: (context, state) => ModeSwitchScreen(
      target: ModeSwitchTarget.fromName(state.uri.queryParameters['to']),
    ),
  ),
];
