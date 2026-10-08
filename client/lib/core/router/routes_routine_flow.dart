import 'package:go_router/go_router.dart';

import '../../features/guardian/domain/routine_stage.dart';
import '../../features/guardian/presentation/card_review_screen.dart';
import '../../features/guardian/presentation/question_screen.dart';
import '../../features/guardian/presentation/reward_setup_screen.dart';
import '../../features/guardian/presentation/routine_input_screen.dart';
import '../../features/guardian/presentation/routine_loading_screen.dart';
import '../../features/guardian/presentation/widgets/aurora_background.dart';
import '../../features/guardian/presentation/widgets/routine_flow_backdrop.dart';
import 'app_transitions.dart';
import 'routes.dart';

/// 일과 만들기 흐름. 흐름 전체가 배경 하나를 함께 쓴다.
List<RouteBase> routineFlowRoutes() => [
  // --- 일과 만들기 흐름 ---
  // 흐름 전체가 **배경 하나**를 함께 쓴다. 화면이 바뀌면 글자만 넘어가고
  // 배경은 그 자리에서 다음 화면 색으로 번진다. 화면마다 배경을 그리면 색이
  // 다른 화면(보상 — 분홍)이 경계선째 밀려 들어온다.
  //
  // 흐름 바깥에서 들어올 때는 흐름 전체가 한 장으로 미끄러져 들어온다.
  // **iOS 뒤로 밀기가 흐름을 통째로 닫지 않게** 전환 페이지로 둔다 — 플랫폼
  // 기본 페이지면 안쪽 화면의 나가기 확인을 건너뛴다.
  ShellRoute(
    pageBuilder: (context, state, child) => slidePage(
      state,
      RoutineFlowBackdrop(
        tone: routineFlowToneOf(state.uri.path),
        child: child,
      ),
    ),
    routes: [
      GoRoute(
        path: Routes.routineInput,
        pageBuilder: (context, state) =>
            flowPage(state, const RoutineInputScreen()),
      ),
      GoRoute(
        path: Routes.routineMasking,
        pageBuilder: (context, state) => flowPage(
          state,
          const RoutineLoadingScreen(kind: RoutineLoadingKind.prepare),
        ),
      ),
      GoRoute(
        path: Routes.routineQuestion,
        pageBuilder: (context, state) =>
            flowPage(state, const QuestionScreen()),
      ),
      GoRoute(
        path: Routes.routineReward,
        // `extra: true`면 카드 검토에서 고치러 온 것이다.
        pageBuilder: (context, state) => flowPage(
          state,
          RewardSetupScreen(fromReview: state.extra == true),
        ),
      ),
      GoRoute(
        path: Routes.routineGenerating,
        pageBuilder: (context, state) => flowPage(
          state,
          const RoutineLoadingScreen(kind: RoutineLoadingKind.generate),
        ),
      ),
      GoRoute(
        path: Routes.routineReview,
        pageBuilder: (context, state) =>
            flowPage(state, const CardReviewScreen()),
      ),
    ],
  ),
];

/// 일과 만들기 흐름에서 [path] 화면이 까는 배경 색.
///
/// 흐름 배경은 라우터가 **맨 위 화면의 위치**로 정한다. 화면이 스스로 알리게
/// 하면 한 프레임 늦어 넘어가는 첫 프레임에 앞 색이 남는다. 색 자체는 화면이
/// 선언한 값을 그대로 가져온다 — 두 곳에 따로 적으면 어긋난다.
AuroraTone routineFlowToneOf(String path) => switch (path) {
  Routes.routineInput => RoutineInputScreen.aurora,
  Routes.routineReward => RewardSetupScreen.aurora,
  Routes.routineMasking => RoutineLoadingScreen.auroraOf(
    RoutineLoadingKind.prepare,
  ),
  Routes.routineQuestion => QuestionScreen.aurora,
  Routes.routineGenerating => RoutineLoadingScreen.auroraOf(
    RoutineLoadingKind.generate,
  ),
  Routes.routineReview => CardReviewScreen.aurora,
  _ => RoutineInputScreen.aurora,
};
