import 'child_home_landscape_body.dart';
import 'child_home_top_bar.dart';
import 'child_routine_group_box.dart';
import 'child_routine_tile.dart';
import 'child_no_routine.dart';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../core/assets/app_assets.dart';
import '../../../core/layout/adaptive_page_frame.dart';
import '../../../core/layout/layout_context_ext.dart';
import '../../../core/layout/screen_layout_kind.dart';
import '../../../core/network/app_failure.dart';
import '../../../core/theme/theme_context_ext.dart';
import '../../../core/widgets/elum_pull_to_refresh.dart';
import '../../../core/widgets/tablet_hero_scene.dart';
import '../../../core/l10n/batchim.dart';
import '../../../core/l10n/l10n_context.dart';
import '../../../shared/models/routine.dart';
import '../../guardian/application/routine_notifier.dart';
import '../../guardian/application/home_routines.dart' show routineProgress;
import '../../onboarding/application/onboarding_notifier.dart';
import '../../profile/application/profile_display_name.dart';
import '../../profile/application/profile_session.dart';
import '../../../shared/models/character.dart';
import '../application/child_home_entries.dart';
import '../application/child_routine_notifier.dart';
import '../application/routine_auto_refresh.dart';
import '../../../core/storage/local_storage.dart';
import '../../member/application/member_providers.dart';
import '../../guardian/application/routine_providers.dart';

/// 아이에게 보여줄 일과 목록.
///
/// `GET /api/routines/today`가 오늘 + CONFIRMED/COMPLETED만 준다.
/// 폴백(전체 조회)으로 내려올 수도 있으므로 **승인 여부를 한 번 더 거른다**
/// (docs 원칙 3번). 방금 만든 일과도 승인 전이면 목록에 없다.
final childRoutinesProvider = Provider<List<Routine>>((ref) {
  final current = ref.watch(routineFlowProvider).routine;
  // `.value`는 재조회 중에도 직전 목록을 유지한다 — 동기화 뒤 깜빡임 방지
  final fetched = ref.watch(todayRoutinesProvider).value ?? const <Routine>[];
  // 보호자 화면에서 만들었던 옛 일과가 남아 있어도 서버의 최신 완료 상태를 가리지 않는다.
  final currentFetched = fetched.any((r) => r.id == current?.id);

  return [
    if (current != null &&
        !currentFetched &&
        current.isConfirmed &&
        current.steps.isNotEmpty)
      current,
    ...fetched.where((r) => r.isVisibleToChild && r.steps.isNotEmpty),
  ];
});

/// Figma `아이_홈_리스트`(356:5079) / `아이_홈_아무것도X`(343:4543).
///
/// 일과 **목록**을 보여주고, 탭하면 카드 상세로 들어간다.
/// 카드 페이저는 [ChildRoutineDetailScreen]으로 내려갔다.
class ChildHomeScreen extends ConsumerWidget {
  const ChildHomeScreen({super.key});

  /// 세로 태블릿 장면 띠 높이 (393 기준)
  static const _portraitSceneHeight = 220.0;

  /// 오늘 일과 받기 실패 코드 (빈 화면 표시 · 당겨서 새로고침 팝업 공통)
  static const _routineListErrorCode = 'E-CHLIST';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final space = context.space;
    final routines = ref.watch(childRoutinesProvider);
    final routinesAsync = ref.watch(todayRoutinesProvider);
    final childName = resolveProfileDisplayName(
      ref.watch(memberProvider).value,
      ref.watch(profileSessionProvider.select((session) => session.selectedId)),
      ref.watch(onboardingProvider).displayName,
    );
    // 온보딩에서 고른 캐릭터. 빈 상태 일러스트가 캐릭터마다 다르다.
    // 아직 안 골랐으면 고양이(루루)로 둔다 — 화면은 떠야 한다.
    final character =
        ref.watch(onboardingProvider).cardCharacter ?? CardCharacter.cat;
    final isElumiDevice = ref.watch(localStorageProvider).isElumiDevice;

    final greetingText = Text(
      // Figma 문구 (1197:6810 · 356:5197).
      //
      // 조사는 이름 받침을 보고 고른다 (보호자가 직접 적은 이름, 예: 민준이가).
      // 시안 문구는 해요체 (`할 일들이에요. 힘내봐요!`).
      context.l10n.childHomeGreeting(childName, batchimOf(childName)),
      // 이 화면 인사말은 22다. 빈 상태 제목(24)과 다르다.
      style: context.typo.childGreeting.copyWith(
        color: context.colors.textPrimary,
      ),
    );

    // 당겨서 새로고침: 오늘 일과만 다시 받기. 실패면 보이던 목록 그대로 + 실패 팝업
    Widget withPullToRefresh(Widget listScroll) => ElumPullToRefresh(
      onRefresh: ref.refreshTodayRoutinesNow,
      failureMessage: context.l10n.todayRoutineLoadFailedFallback,
      failureCode: _routineListErrorCode,
      child: listScroll,
    );

    // 가로 태블릿은 왼쪽 인사말·오른쪽 목록 두 칸. 낮은 창(분할 보기)은 한 열 스크롤로 접는다
    final metrics = context.layoutMetrics;
    final hasTwoPanes =
        metrics.isScaleOverridden &&
        metrics.isLandscape &&
        !metrics.isShortHeight;

    // 태블릿에서 두 칸이 아니면 가운데 열(폭 상한)에 담는다. 폰은 그대로 지나간다
    return AdaptivePageFrame(
      kind: hasTwoPanes
          ? ScreenLayoutKind.adaptive
          : ScreenLayoutKind.contentColumn,
      // 보호자가 새 일과를 저장해도 앱을 껐다 켜야 보였다 — 떠 있는 동안 주기 갱신
      child: RoutineAutoRefresh(
        child: Scaffold(
          backgroundColor: context.colors.background,
          body: SafeArea(
            child: routines.isEmpty
                ? Column(
                    children: [
                      const ChildHomeTopBar(),
                      Expanded(
                        child: withPullToRefresh(
                          ChildNoRoutine(
                            childName: childName,
                            character: character,
                            isElumiDevice: isElumiDevice,
                            // 조회가 실패했으면 제보 추적용 코드를 함께 보여준다.
                            // 아동 화면이라 빨강·경고 아이콘은 쓰지 않는다.
                            // 코드는 실제로 무엇이 터졌는지를 쓴다 — 연결이 끊긴 것과
                            // 서버가 막은 것이 같은 코드로 보이면 제보를 못 가린다.
                            errorCode: routinesAsync.hasError
                                ? AppFailure.of(
                                    routinesAsync.error,
                                  ).badgeOr(_routineListErrorCode)
                                : null,
                          ),
                        ),
                      ),
                    ],
                  )
                : hasTwoPanes
                ? Column(
                    children: [
                      const ChildHomeTopBar(),
                      Expanded(
                        child: ChildHomeLandscapeBody(
                          greeting: greetingText,
                          character: character,
                          routineList: _RoutineList(routines: routines),
                          listScrollWrapper: withPullToRefresh,
                        ),
                      ),
                    ],
                  )
                : withPullToRefresh(
                    SingleChildScrollView(
                      physics: ElumPullToRefresh.calmPhysics,
                      padding: EdgeInsets.only(bottom: space.xl),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const ChildHomeTopBar(),
                          // 시안(1197:6810)은 인사말이 y150 에서 시작한다. 상단 줄 아래(122)에서 28.
                          SizedBox(height: 28.h),
                          Padding(
                            padding: EdgeInsets.symmetric(
                              horizontal: space.screenH,
                            ),
                            child: greetingText,
                          ),
                          // 세로 태블릿: 인사말 아래 장면 띠 (폰은 없음)
                          if (metrics.isScaleOverridden) ...[
                            SizedBox(height: space.lg),
                            Padding(
                              padding: EdgeInsets.symmetric(
                                horizontal: space.md,
                              ),
                              child: SizedBox(
                                height: _portraitSceneHeight.h,
                                child: TabletHeroScene(
                                  characterAsset: AppAssets.character(
                                    character,
                                  ),
                                  characterHeightRatio: 0.62,
                                ),
                              ),
                            ),
                          ],
                          // 인사말 아래(202) → 첫 타일(242)
                          SizedBox(height: 40.h),
                          Padding(
                            padding: EdgeInsets.symmetric(horizontal: space.md),
                            child: _RoutineList(routines: routines),
                          ),
                        ],
                      ),
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}

/// 일과 타일 목록 (Figma 361×68, 간격 16). 묶음으로 보낸 일과는 상자 하나로 묶어 보인다 (#808)
class _RoutineList extends ConsumerWidget {
  const _RoutineList({required this.routines});

  final List<Routine> routines;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final space = context.space;
    final progress = ref.watch(childRoutineProvider);
    double progressOf(Routine routine) => routineProgress(routine, progress);
    final entries = composeChildHomeEntries(routines);

    return Column(
      children: [
        for (final (index, entry) in entries.indexed) ...[
          if (index > 0) SizedBox(height: space.md),
          switch (entry) {
            ChildRoutineEntry(:final routine) => ChildRoutineTile(
              routine: routine,
              progress: progressOf(routine),
            ),
            ChildGroupEntry() => ChildRoutineGroupBox(
              entry: entry,
              progressOf: progressOf,
            ),
          },
        ],
      ],
    );
  }
}
