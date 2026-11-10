import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/assets/app_assets.dart';
import '../../../../core/l10n/l10n_context.dart';
import '../../../../core/layout/app_text_scale.dart';
import '../../../../core/layout/layout_context_ext.dart';
import '../../../../core/layout/window_size_class.dart';
import '../../../../core/router/routes.dart';
import '../../../../core/theme/theme_context_ext.dart';
import '../../../../core/widgets/app_pressable.dart';
import '../../../../core/widgets/character_badge.dart';
import '../../../../core/widgets/elum_floating_pill_button.dart';
import '../../../../core/widgets/elum_spinner.dart';
import '../../../member/application/plan_access.dart';
import '../../../subscription/domain/plan_benefit.dart';
import '../../application/guardian_child_identity.dart';
import '../../application/routine_schedule_controller.dart';
import '../../application/routine_manage_coach_notifier.dart';
import 'coach_help_button.dart';
import 'grey_tile_shell.dart';
import 'library_entry_pill.dart';

// 일과관리 칸 화면 조각: 머리, 빈 상태, `+ 일과 만들기` 버튼 (#805). 격자는 library_entry_grid.dart

/// 제목 + 오른쪽 `주간 계획`·`전문가 일과` 입구(Pro) + (폰만) 오른쪽 위 이룸이 화면 배지. 태블릿은 옆 메뉴에 입구가 있다
class LibraryManageHeader extends ConsumerWidget {
  const LibraryManageHeader();

  /// 입구 2개를 제목 옆 한 줄에 둘 수 있는 최소 폭 (393 폰은 제목이 한 글자씩 꺾여 아래 줄로 내림)
  static const _twoEntriesInlineMinWidth = 480.0;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final space = context.space;
    final isPhone = context.sizeClass == WindowSizeClass.compact;
    final identity = ref.watch(guardianChildIdentityProvider);
    // 입구: 주간 계획 (Pro 이거나 정해 둔 반복이 있을 때) · Free 면 Pro 배지
    final access = ref.watch(planAccessProvider);
    final entries = <Widget>[
      if (ref.watch(canShowRoutineScheduleProvider))
        LibraryEntryPill(
          label: context.l10n.weeklyPlanEntry,
          iconAsset: AppAssets.iconCalendar,
          shouldShowProBadge: access.shouldShowTeaserFor(PlanBenefit.routineSchedule),
          onTap: () => context.push(Routes.guardianWeeklyPlan),
        ),
    ];
    // 제목 + 사용법(코치마크) 다시 보기 `?`
    final title = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Flexible(
          child: Text(
            context.l10n.guardianTabManage,
            // 제목은 한 줄을 지킨다 (입구 알약이 줄어들어 자리를 내줌)
            maxLines: 1,
            softWrap: false,
            overflow: TextOverflow.ellipsis,
            style: context.typo.libraryTitle.copyWith(
              color: context.colors.textPrimary,
            ),
          ),
        ),
        SizedBox(width: space.xs.w),
        CoachHelpButton(
          onTap: () => ref
              .read(routineManageCoachProvider.notifier)
              .requestReplay(),
        ),
      ],
    );
    final badge = isPhone
        ? AppPressable(
            onTap: () => context.go(Routes.child),
            scaleDown: AppPressable.scaleIcon,
            semanticLabel: context.l10n.guardianHomeGoChildScreen,
            child: CharacterBadge(character: identity.character),
          )
        : null;

    return Padding(
      padding: EdgeInsets.fromLTRB(
        space.screenH.w,
        space.sm.h,
        space.screenH.w,
        0,
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final shouldStackEntries = entries.isNotEmpty &&
              (AppTextScale.isLargeTextOf(context) || (entries.length >= 2 && constraints.maxWidth < _twoEntriesInlineMinWidth));
          if (shouldStackEntries) {
            // 제목·배지 한 줄 > 입구 줄 (좁으면 또 내림)
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(children: [Expanded(child: title), ?badge]),
                SizedBox(height: space.xs.h),
                Wrap(spacing: space.xs.w, runSpacing: space.xs.h, children: entries),
              ],
            );
          }
          return Row(
            children: [
              title,
              // 제목이 먼저 자리를 잡고, 남는 폭 안에서 입구가 줄어든다
              Expanded(
                child: Align(
                  alignment: Alignment.centerRight,
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Row(children: entries),
                  ),
                ),
              ),
              if (isPhone && entries.isNotEmpty) SizedBox(width: space.xs.w),
              ?badge,
            ],
          );
        },
      ),
    );
  }
}

/// 원본이 하나도 없을 때 (시안 217:2655): 목록 첫 줄 자리에 글만 든 웜그레이 줄
/// 보호자 화면 빈 상태는 그림 없이 홈 `EmptyRoutines` 와 같은 칸을 쓴다
class LibraryEmptyState extends StatelessWidget {
  const LibraryEmptyState({required this.bottomSpace});

  final double bottomSpace;

  /// 빈 상태 두 줄 사이 (홈 `EmptyRoutines` 와 같다)
  static const _lineGap = 8.0;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typo = context.typo;
    final space = context.space;
    // 격자 첫 칸과 같은 자리 (판 x=16 · 위 12)
    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(
        space.md.w,
        space.sm.h,
        space.md.w,
        bottomSpace,
      ),
      child: GreyTileShell(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              context.l10n.routineLibraryEmptyTitle,
              style: typo.routineEmptyTitle.copyWith(
                color: colors.routineTileLabel,
              ),
            ),
            SizedBox(height: _lineGap.h),
            Text(
              context.l10n.routineLibraryEmptyBody,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: typo.routineTileMeta.copyWith(
                color: colors.routineEmptyHint,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 가운데 아래 `+ 새로 만들기` (글자가 있는 둥근 버튼 — 무엇을 하는지 바로 보이게, 시안 1664:6876)
class CreateRoutineFab extends StatelessWidget {
  const CreateRoutineFab({
    required this.isBusy,
    required this.onTap,
    this.isArranging = false,
  });

  final bool isBusy;
  final VoidCallback onTap;

  /// 정리 상태면 `+ 새로 만들기` 대신 `완료`가 된다 (#837)
  final bool isArranging;

  /// 버튼 높이 · 아래 여백 · 자리: 이야기 `+ 올리기` 와 같은 알약 (#964)
  static const height = ElumFloatingPillButton.height;
  static const scrollBottomSpace = ElumFloatingPillButton.scrollBottomSpace;
  static const FloatingActionButtonLocation location =
      ElumFloatingPillButton.location;

  @override
  Widget build(BuildContext context) {
    final iconSize = ElumFloatingPillButton.iconSize.w;
    return ElumFloatingPillButton(
      label: isArranging
          ? context.l10n.libraryArrangeDone
          : context.l10n.routineLibraryCreate,
      onTap: isBusy ? null : onTap,
      leading: isBusy
          ? ElumSpinner(size: iconSize, color: context.colors.buttonEnabledText)
          : isArranging
          ? null
          : const ElumFloatingPillPlusIcon(),
    );
  }
}
