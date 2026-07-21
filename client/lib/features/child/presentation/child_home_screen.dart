import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';

import '../../../core/assets/app_assets.dart';
import '../../../core/router/app_router.dart';
import '../../../core/theme/theme_context_ext.dart';
import '../../../core/widgets/app_pressable.dart';
import '../../../core/widgets/routine_progress_ring.dart';
import '../../../shared/models/routine.dart';
import '../../guardian/application/routine_notifier.dart';
import '../../guardian/data/routine_repository.dart';
import '../../guardian/presentation/widgets/today_routine_section.dart'
    show routineProgress;
import '../../onboarding/application/onboarding_notifier.dart';
import '../../onboarding/domain/character.dart';
import '../application/child_routine_notifier.dart';
import 'mode_switch_screen.dart';

/// 아이에게 보여줄 일과 목록.
///
/// `GET /api/routines/today`(이슈 #75)가 오늘 + CONFIRMED/COMPLETED만 준다.
/// 폴백(전체 조회)으로 내려올 수도 있으므로 **승인 여부를 한 번 더 거른다**
/// (docs 원칙 3번). 방금 만든 일과도 승인 전이면 목록에 없다.
final childRoutinesProvider = Provider<List<Routine>>((ref) {
  final current = ref.watch(routineFlowProvider).routine;
  final fetched =
      ref.watch(todayRoutinesProvider).asData?.value ?? const <Routine>[];

  return [
    if (current != null && current.isConfirmed && current.steps.isNotEmpty)
      current,
    ...fetched.where(
      (r) => r.id != current?.id && r.isVisibleToChild && r.steps.isNotEmpty,
    ),
  ];
});

/// Figma `아이_홈_리스트`(356:5079) / `아이_홈_아무것도X`(343:4543).
///
/// 일과 **목록**을 보여주고, 탭하면 카드 상세로 들어간다 (이슈 #69).
/// 카드 페이저는 [ChildRoutineDetailScreen]으로 내려갔다.
class ChildHomeScreen extends ConsumerWidget {
  const ChildHomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final space = context.space;
    final routines = ref.watch(childRoutinesProvider);
    final routinesAsync = ref.watch(todayRoutinesProvider);
    final localName = ref.watch(onboardingProvider).displayName;
    final childName = ref
        .watch(memberProvider)
        .maybeWhen(
          data: (member) => member?.nickname ?? localName,
          orElse: () => localName,
        );

    return Scaffold(
      backgroundColor: context.colors.background,
      body: SafeArea(
        child: routines.isEmpty
            ? Column(
                children: [
                  const _TopBar(),
                  Expanded(
                    child: _NoRoutine(
                      childName: childName,
                      // 조회가 실패했으면 제보 추적용 코드를 함께 보여준다.
                      // 아동 화면이라 빨강·경고 아이콘은 쓰지 않는다.
                      errorCode: routinesAsync.hasError ? 'E-CHLIST' : null,
                    ),
                  ),
                ],
              )
            : SingleChildScrollView(
                padding: EdgeInsets.only(bottom: space.xl),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const _TopBar(),
                    SizedBox(height: space.xl),
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: space.screenH),
                      child: Text(
                        // Figma 문구 (356:5197) — 이름 뒤 조사는 displayName이
                        // '하늘이' 꼴이라 '가'로 이어진다.
                        '오늘 $childName가\n할 일들이야. 힘내보자!',
                        style: context.typo.greeting.copyWith(
                          color: context.colors.textPrimary,
                        ),
                      ),
                    ),
                    SizedBox(height: space.xl),
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: space.md),
                      child: _RoutineList(routines: routines),
                    ),
                  ],
                ),
              ),
      ),
    );
  }
}

/// 로고 + 별 배지 + 캐릭터 배지 (Figma 356:5079 상단).
class _TopBar extends ConsumerWidget {
  const _TopBar();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final space = context.space;
    // 별 개수. 조회 실패해도 0으로 화면은 뜬다 (docs 원칙 6번)
    final stars = ref
        .watch(memberProvider)
        .maybeWhen(data: (member) => member?.totalStars ?? 0, orElse: () => 0);
    // 온보딩에서 고른 캐릭터. 배지 테두리 색이 캐릭터마다 다르다.
    // 아직 안 골랐으면 고양이(루루)로 둔다 — 화면은 떠야 한다.
    final character =
        ref.watch(onboardingProvider).cardCharacter ?? CardCharacter.cat;

    return Padding(
      padding: EdgeInsets.fromLTRB(space.screenH, space.md, space.screenH, 0),
      child: Row(
        children: [
          SvgPicture.asset(AppAssets.homeLogo, width: 80.w, height: 30.h),
          const Spacer(),
          // 별 배지 — 탭하면 누적 별 화면으로 (Figma 364:8219)
          AppPressable(
            onTap: () => context.push(Routes.childStars),
            scaleDown: AppPressable.scaleIcon,
            child: _StarBadge(count: stars),
          ),
          SizedBox(width: space.md),
          // 보호자로 돌아가려면 암호가 필요하다
          AppPressable(
            onTap: () => context.push(
              '${Routes.modeSwitch}?to=${ModeSwitchTarget.guardian.name}',
            ),
            scaleDown: AppPressable.scaleIcon,
            // 정사각형 배지라 가로세로 모두 .w
            child: SvgPicture.asset(
              AppAssets.characterBadgeFramed(character),
              width: 56.w,
              height: 56.w,
            ),
          ),
        ],
      ),
    );
  }
}

/// 별 배지 (Figma 364:8531 — 50×48 SVG 위에 숫자를 겹친다).
class _StarBadge extends StatelessWidget {
  const _StarBadge({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 50.w,
      height: 48.w,
      child: Stack(
        alignment: Alignment.center,
        children: [
          SvgPicture.asset(AppAssets.starBadge, width: 50.w, height: 48.w),
          Padding(
            // 별 무게중심이 약간 위라 숫자를 살짝 내린다 (Figma y=91-74=17)
            padding: EdgeInsets.only(top: 4.h),
            child: Text(
              '$count',
              style: context.typo.subtitle.copyWith(
                color: context.colors.starCount,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 일과 타일 목록 (Figma 361×68, 간격 16).
class _RoutineList extends ConsumerWidget {
  const _RoutineList({required this.routines});

  final List<Routine> routines;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final space = context.space;
    final progress = ref.watch(childRoutineProvider);

    return Column(
      children: [
        for (final (index, routine) in routines.indexed) ...[
          if (index > 0) SizedBox(height: space.md),
          _RoutineTile(
            routine: routine,
            progress: routineProgress(routine, progress.completed),
          ),
        ],
      ],
    );
  }
}

/// 일과 한 줄 (Figma 356:5079).
///
/// 미완료는 회색 + 진행률 링, 전부 끝내면 민트 배경 + 채운 체크.
/// 탭하면 카드 상세로 들어간다.
class _RoutineTile extends StatelessWidget {
  const _RoutineTile({required this.routine, required this.progress});

  final Routine routine;
  final double progress;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final space = context.space;
    final isDone = progress >= 1.0;

    return AppPressable(
      onTap: () => context.push(Routes.childRoutineDetail, extra: routine),
      scaleDown: AppPressable.scaleCard,
      child: Container(
        height: 68.h,
        // Figma 실측 — 제목 좌 24, 화살표 우 16
        padding: EdgeInsets.only(left: 24.w, right: 16.w),
        decoration: BoxDecoration(
          color: isDone ? colors.childTileDone : colors.routineTileBg,
          borderRadius: BorderRadius.circular(space.cardRadius),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                routine.displayTitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: context.typo.childTileTitle.copyWith(
                  color: colors.chipLabel,
                ),
              ),
            ),
            SizedBox(width: space.xs),
            RoutineProgressRing(progress: progress),
            SizedBox(width: space.xs),
            // 아래 방향 원본을 반시계 90° 돌려 `>`로 만든다
            Transform.rotate(
              angle: -math.pi / 2,
              child: SvgPicture.asset(
                AppAssets.iconAngleSmall,
                width: 24.w,
                height: 24.w,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 보호자가 아직 일과를 만들지 않았다 (Figma 343:4543).
class _NoRoutine extends StatelessWidget {
  const _NoRoutine({required this.childName, this.errorCode});

  final String childName;

  /// 조회 실패 시 제보 추적용 코드. null이면 표시하지 않는다.
  final String? errorCode;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    // 작은 화면·큰 글꼴에서도 넘치지 않게 스크롤로 감싼다
    return Center(
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '아직 $childName의\n일과가 없어요',
              textAlign: TextAlign.center,
              style: context.typo.greeting.copyWith(color: colors.textPrimary),
            ),
            SizedBox(height: 16.h),
            Text(
              '보호자 화면에서 일과를 만들 수 있어요',
              style: context.typo.body.copyWith(color: colors.textSecondary),
            ),
            if (errorCode != null) ...[
              SizedBox(height: 8.h),
              Text(
                '($errorCode)',
                style: context.typo.caption.copyWith(
                  color: colors.textSecondary,
                ),
              ),
            ],
            SizedBox(height: 48.h),
            // 캐릭터 뒤 은은한 빛 — 단순 원이라 코드로 그린다 (blur 100)
            SizedBox(
              width: 200.w,
              height: 200.w,
              child: Stack(
                alignment: Alignment.center,
                clipBehavior: Clip.none,
                children: [
                  ImageFiltered(
                    imageFilter: ImageFilter.blur(sigmaX: 40.w, sigmaY: 40.w),
                    child: Container(
                      width: 180.w,
                      height: 180.w,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: colors.catSelectedFill,
                      ),
                    ),
                  ),
                  // 시무룩한 루루 — 형태가 있는 일러스트는 반드시 에셋 (Figma 382:3220)
                  SvgPicture.asset(
                    AppAssets.ruruSad,
                    width: 164.w,
                    height: 164.w,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
