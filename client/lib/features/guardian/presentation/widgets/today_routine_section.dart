import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../../core/assets/app_assets.dart';
import '../../../../core/theme/app_motion.dart';
import '../../../../core/theme/theme_context_ext.dart';
import '../../../../core/widgets/app_pressable.dart';
import '../../../../core/widgets/routine_progress_ring.dart';
import '../../../../shared/models/action_card.dart';
import '../../../child/application/child_routine_notifier.dart';
import '../../../onboarding/application/onboarding_notifier.dart';
import '../../../onboarding/domain/character.dart';
import '../../application/routine_notifier.dart';
import '../../data/routine_repository.dart';
import '../../domain/card_palette.dart';
import '../../../../shared/models/routine.dart';

// (참고) 제목 fallback은 Routine.displayTitle이 처리한다.

/// 홈에 보여줄 일과 목록 — 방금 만든 일과 + 서버 목록을 병합한다.
///
/// 방금 만든 일과를 먼저 둔다. 서버 목록 갱신을 기다리면 승인 직후 홈에
/// 아무것도 없는 것처럼 보인다 (docs 원칙 6번 — 데모는 끊기지 않는다).
/// steps가 빈 일과는 펼쳐도 보여줄 것이 없어 제외한다.
final homeRoutinesProvider = Provider<List<Routine>>((ref) {
  final current = ref.watch(routineFlowProvider).routine;
  final fetched = ref.watch(myRoutinesProvider).asData?.value ?? const <Routine>[];

  return [
    if (current != null && current.steps.isNotEmpty) current,
    ...fetched.where((r) => r.id != current?.id && r.steps.isNotEmpty),
  ];
});

/// 일과의 진행률(0.0~1.0).
///
/// 서버 `completed`와 아이 모드의 로컬 체크를 합친다 — 서버 반영이 늦어도
/// 방금 체크한 카드가 진행률에 바로 보여야 한다.
double routineProgress(Routine routine, Set<String> localCompleted) {
  if (routine.steps.isEmpty) return 0;
  final done = routine.steps
      .where((s) => s.completed || localCompleted.contains(s.id))
      .length;
  return done / routine.steps.length;
}

/// 보호자 홈 "오늘 일과" 섹션 (Figma 356:4688 접힘 / 309:3739 펼침 / 217:2655 빈).
///
/// 일과 여러 개를 접힌 타일로 나열하고, 탭하면 그 일과만 펼쳐 카드 목록을
/// 보여준다. **한 번에 하나만 펼친다** — 여러 개가 열리면 화면이 끝없이 길어진다.
class TodayRoutineSection extends ConsumerStatefulWidget {
  const TodayRoutineSection({super.key});

  @override
  ConsumerState<TodayRoutineSection> createState() =>
      _TodayRoutineSectionState();
}

class _TodayRoutineSectionState extends ConsumerState<TodayRoutineSection> {
  /// 펼쳐진 일과 id. null이면 전부 접힘 (Figma 기본 상태 356:4688).
  String? _expandedId;

  void _toggle(String id) {
    setState(() => _expandedId = _expandedId == id ? null : id);
  }

  @override
  Widget build(BuildContext context) {
    final routines = ref.watch(homeRoutinesProvider);
    final space = context.space;

    if (routines.isEmpty) {
      final async = ref.watch(myRoutinesProvider);
      // 로딩과 빈 상태를 구분한다 — 무한 로딩처럼 보이면 안 된다.
      // 조회 실패도 빈 상태로 흡수해 화면이 붉게 덮이지 않게 한다.
      return async.isLoading ? const _LoadingTile() : const EmptyRoutines();
    }

    final progress = ref.watch(childRoutineProvider);

    return Column(
      children: [
        for (final (index, routine) in routines.indexed) ...[
          if (index > 0) SizedBox(height: space.md),
          // 펼침/접힘 전환이 뚝 끊기지 않게 크기를 애니메이션한다
          AnimatedSize(
            duration: AppMotion.normal,
            curve: AppMotion.standard,
            alignment: Alignment.topCenter,
            child: routine.id == _expandedId
                ? _ExpandedRoutine(
                    routine: routine,
                    completed: progress.completed,
                    onCollapse: () => _toggle(routine.id),
                  )
                : _CollapsedTile(
                    routine: routine,
                    progress: routineProgress(routine, progress.completed),
                    onTap: () => _toggle(routine.id),
                  ),
          ),
        ],
      ],
    );
  }
}

/// 접힌 일과 타일 (Figma 356:4688 — 361×68, r20, #EEE9E6).
class _CollapsedTile extends StatelessWidget {
  const _CollapsedTile({
    required this.routine,
    required this.progress,
    required this.onTap,
  });

  final Routine routine;
  final double progress;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final space = context.space;

    return AppPressable(
      onTap: onTap,
      scaleDown: AppPressable.scaleCard,
      child: Container(
        height: 68.h,
        // Figma 실측 — 제목 좌 24, 화살표 우 16
        padding: EdgeInsets.only(left: 24.w, right: 16.w),
        decoration: BoxDecoration(
          color: colors.routineTileBg,
          borderRadius: BorderRadius.circular(space.cardRadius),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                routine.displayTitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: context.typo.body.copyWith(color: colors.chipLabel),
              ),
            ),
            SizedBox(width: space.xs),
            RoutineProgressRing(progress: progress),
            SizedBox(width: space.xs),
            // 원본 SVG가 아래 방향이라 접힘 상태 그대로 쓴다
            SvgPicture.asset(AppAssets.iconAngleSmall, width: 24.w, height: 24.w),
          ],
        ),
      ),
    );
  }
}

/// 펼쳐진 일과 (Figma 309:3739 Group 47 — 361 폭, r28, #EEE9E6 컨테이너).
class _ExpandedRoutine extends ConsumerWidget {
  const _ExpandedRoutine({
    required this.routine,
    required this.completed,
    required this.onCollapse,
  });

  final Routine routine;
  final Set<String> completed;
  final VoidCallback onCollapse;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final space = context.space;

    return Container(
      // Figma 실측 — 컨테이너 안쪽 여백 8, 카드 목록이 그 안에 들어간다
      padding: EdgeInsets.fromLTRB(8.w, 0, 8.w, 8.w),
      decoration: BoxDecoration(
        color: colors.routineTileBg,
        borderRadius: BorderRadius.circular(28.w),
      ),
      child: Column(
        children: [
          // 제목 헤더 — 탭하면 접힌다
          AppPressable(
            onTap: onCollapse,
            child: Padding(
              // Figma 실측 — 제목 y=26, 좌 16(컨테이너 8 + 16 = 24)
              padding: EdgeInsets.fromLTRB(16.w, 22.h, 0, 12.h),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      routine.displayTitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style:
                          context.typo.body.copyWith(color: colors.chipLabel),
                    ),
                  ),
                  // 펼침 상태 — 위 방향 (원본을 180° 돌린다)
                  Transform.rotate(
                    angle: 3.14159,
                    child: SvgPicture.asset(
                      AppAssets.iconAngleSmall,
                      width: 24.w,
                      height: 24.w,
                    ),
                  ),
                  SizedBox(width: 8.w),
                ],
              ),
            ),
          ),
          for (final (index, card) in routine.steps.indexed) ...[
            if (index > 0) SizedBox(height: space.xs),
            _CardRow(
              card: card,
              index: index,
              isDone: card.completed || completed.contains(card.id),
            ),
          ],
        ],
      ),
    );
  }
}

/// 카드 한 줄 — 번호 + 제목 + 설명 + 완료 표시 (Figma 344×68, 흰 배경).
class _CardRow extends StatelessWidget {
  const _CardRow({
    required this.card,
    required this.index,
    required this.isDone,
  });

  final ActionCard card;
  final int index;

  /// 아이가 완료했는가. 완료하면 우측에 체크가 채워진다.
  final bool isDone;

  /// Figma 실측 — 번호 배지 40×40 r12
  static const _badgeSize = 40.0;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final space = context.space;
    final palette = CardPalette.at(index);

    return Container(
      height: 68.h,
      padding: EdgeInsets.symmetric(horizontal: space.md),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(space.cardRadius),
        border: Border.all(color: colors.border),
      ),
      child: Row(
        children: [
          Container(
            // 정사각형 배지 — 가로세로 모두 .w
            width: _badgeSize.w,
            height: _badgeSize.w,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: palette.border,
              borderRadius: BorderRadius.circular(12.w),
            ),
            child: Text(
              '${index + 1}',
              style: context.typo.cardHeadline.copyWith(color: colors.surface),
            ),
          ),
          SizedBox(width: space.sm),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  card.displayTitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: context.typo.cardBody.copyWith(color: colors.chipLabel),
                ),
                SizedBox(height: space.xs),
                Text(
                  card.description,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style:
                      context.typo.caption.copyWith(color: colors.textSecondary),
                ),
              ],
            ),
          ),
          // 아이가 끝낸 카드만 채워진 체크가 된다
          _DoneMark(isDone: isDone),
        ],
      ),
    );
  }
}

/// 완료 표시 (40×40). 미완료는 흐린 원, 완료는 채워진 체크.
class _DoneMark extends StatelessWidget {
  const _DoneMark({required this.isDone});

  final bool isDone;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return AnimatedContainer(
      duration: AppMotion.fast,
      curve: AppMotion.standard,
      // 원형 표시 — 가로세로 모두 .w
      width: 40.w,
      height: 40.w,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: isDone ? colors.checkDone : Colors.transparent,
        border:
            isDone ? null : Border.all(color: colors.checkPending, width: 2.w),
      ),
      child: Icon(
        Icons.check_rounded,
        size: 22.w,
        color: isDone ? colors.surface : colors.checkPending,
      ),
    );
  }
}

/// Figma 빈 상태 (217:2655 — 344×68, #EEE9E6) — `아직 만든 일과가 없어요 😢`
class EmptyRoutines extends ConsumerWidget {
  const EmptyRoutines({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final space = context.space;
    final profile = ref.watch(onboardingProvider);
    final childName = profile.displayName;
    // 온보딩에서 고른 캐릭터를 그대로 쓴다 — 홈 전역 마스코트와 통일 (아이 홈과 동일 폴백).
    final character = profile.cardCharacter ?? CardCharacter.cat;

    return _GreyTileShell(
      child: Row(
        children: [
          // 정사각형 일러스트 — 가로세로 모두 .w
          SvgPicture.asset(
            AppAssets.characterBadgeFramed(character),
            width: 40.w,
            height: 40.w,
          ),
          SizedBox(width: space.md),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '아직 만든 일과가 없어요 😢',
                  style: context.typo.cardBody
                      .copyWith(color: context.colors.chipLabel),
                ),
                SizedBox(height: space.xs),
                Text(
                  '$childName의 첫 행동카드를 만들어보세요',
                  style: context.typo.caption
                      .copyWith(color: context.colors.textSecondary),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// 목록 조회 중. 빈 상태와 구분되는 자리 표시.
class _LoadingTile extends StatelessWidget {
  const _LoadingTile();

  @override
  Widget build(BuildContext context) {
    return _GreyTileShell(
      child: Center(
        child: SizedBox(
          width: 20.w,
          height: 20.w,
          child: CircularProgressIndicator(strokeWidth: 2.w),
        ),
      ),
    );
  }
}

/// 빈 상태·로딩의 회색 껍데기 (Figma 217:2691 — 344×68, r20, #EEE9E6).
class _GreyTileShell extends StatelessWidget {
  const _GreyTileShell({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final space = context.space;

    return Container(
      height: 68.h,
      padding: EdgeInsets.symmetric(horizontal: space.md),
      decoration: BoxDecoration(
        color: context.colors.routineTileBg,
        borderRadius: BorderRadius.circular(space.cardRadius),
      ),
      child: child,
    );
  }
}
