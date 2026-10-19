import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/l10n/l10n_context.dart';
import '../../../../core/layout/layout_context_ext.dart';
import '../../../../core/layout/window_size_class.dart';
import '../../../../core/router/routes.dart';
import '../../../../core/theme/theme_context_ext.dart';
import '../../../../core/widgets/app_pressable.dart';
import '../../../../core/widgets/character_badge.dart';
import '../../../../core/widgets/elum_spinner.dart';
import '../../../../shared/models/routine.dart';
import '../../application/guardian_child_identity.dart';
import 'library_routine_tile.dart';

// 일과관리 칸 화면 조각: 머리, 격자, 빈 상태, `+ 일과 만들기` 버튼 (#805)

/// 제목 + (폰만) 오른쪽 위 이룸이 화면 배지. 태블릿은 옆 메뉴에 입구가 있다
class LibraryManageHeader extends ConsumerWidget {
  const LibraryManageHeader();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final space = context.space;
    final isPhone = context.sizeClass == WindowSizeClass.compact;
    final identity = ref.watch(guardianChildIdentityProvider);
    return Padding(
      padding: EdgeInsets.fromLTRB(
        space.screenH.w,
        space.sm.h,
        space.screenH.w,
        0,
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              context.l10n.guardianTabManage,
              style: context.typo.greeting.copyWith(
                color: context.colors.textPrimary,
              ),
            ),
          ),
          if (isPhone)
            AppPressable(
              onTap: () => context.go(Routes.child),
              scaleDown: AppPressable.scaleIcon,
              semanticLabel: context.l10n.guardianHomeGoChildScreen,
              child: CharacterBadge(character: identity.character),
            ),
        ],
      ),
    );
  }
}

/// 원본 격자. 창 폭으로 열 수를 정한다 (폰 4열, 넓으면 늘어남)
class LibraryGrid extends StatelessWidget {
  const LibraryGrid({
    required this.routines,
    required this.sentIds,
    required this.bottomSpace,
    required this.onTap,
    required this.onLongPress,
  });

  final List<Routine> routines;
  final Set<String> sentIds;
  final double bottomSpace;

  /// 다른 동작이 도는 중이면 null — 같은 요청이 두 번 가지 않게
  final ValueChanged<Routine>? onTap;
  final ValueChanged<Routine>? onLongPress;

  /// 칸 한 개가 차지하는 최소 폭(393 기준). 이 폭으로 열 수를 정한다 (폰 4열)
  static const _tileMinWidth = 84.0;
  static const _minColumns = 4;
  static const _maxColumns = 8;

  @override
  Widget build(BuildContext context) {
    final space = context.space;
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns =
            (constraints.maxWidth / _tileMinWidth.w)
                .floor()
                .clamp(
                  _minColumns,
                  _maxColumns,
                );
        return GridView.builder(
          padding: EdgeInsets.fromLTRB(
            space.md.w,
            space.xs.h,
            space.md.w,
            bottomSpace,
          ),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: columns,
            mainAxisSpacing: space.md.h,
            crossAxisSpacing: space.xs.w,
            // 그림 칸 + 이름 두 줄이 들어가는 높이
            mainAxisExtent:
                LibraryRoutineTile.iconSize.w + space.xs.h + space.xl.h * 1.4,
          ),
          itemCount: routines.length,
          itemBuilder: (context, index) {
            final routine = routines[index];
            return LibraryRoutineTile(
              key: ValueKey(routine.id),
              routine: routine,
              isSentToday: sentIds.contains(routine.id),
              onTap: () => onTap?.call(routine),
              onLongPress: () => onLongPress?.call(routine),
            );
          },
        );
      },
    );
  }
}

/// 원본이 하나도 없을 때 (불러오는 중·실패와 구분되는 빈 상태)
class LibraryEmptyState extends StatelessWidget {
  const LibraryEmptyState({required this.bottomSpace});

  final double bottomSpace;

  /// 안내 아이콘 한 변
  static const _iconSize = 56.0;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final space = context.space;
    return Padding(
      padding: EdgeInsets.only(
        left: space.screenH.w,
        right: space.screenH.w,
        bottom: bottomSpace,
      ),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.folder_outlined,
              size: _iconSize.w,
              color: colors.navIconUnselected,
            ),
            SizedBox(height: space.md.h),
            Text(
              context.l10n.routineLibraryEmptyTitle,
              textAlign: TextAlign.center,
              style: context.typo.sectionTitle.copyWith(
                color: colors.textPrimary,
              ),
            ),
            SizedBox(height: space.xs.h),
            Text(
              context.l10n.routineLibraryEmptyBody,
              textAlign: TextAlign.center,
              style: context.typo.body.copyWith(color: colors.textSecondary),
            ),
          ],
        ),
      ),
    );
  }
}

/// 가운데 아래 `+ 일과 만들기` (글자가 있는 둥근 버튼 — 무엇을 하는지 바로 보이게)
class CreateRoutineFab extends StatelessWidget {
  const CreateRoutineFab({
    required this.height,
    required this.isBusy,
    required this.onTap,
  });

  final double height;
  final bool isBusy;
  final VoidCallback onTap;

  /// 더하기 아이콘 한 변
  static const _iconSize = 24.0;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final space = context.space;
    return AppPressable(
      onTap: isBusy ? null : onTap,
      child: Container(
        height: height,
        padding: EdgeInsets.symmetric(horizontal: space.lg.w),
        decoration: BoxDecoration(
          color: colors.textPrimary,
          borderRadius: BorderRadius.circular(height / 2),
          boxShadow: [
            BoxShadow(
              color: colors.textPrimary.withValues(alpha: 0.3),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isBusy)
              ElumSpinner(size: _iconSize.w, color: colors.surface)
            else
              Icon(Icons.add_rounded, size: _iconSize.w, color: colors.surface),
            SizedBox(width: space.xs.w),
            Text(
              context.l10n.routineLibraryCreate,
              style: context.typo.button.copyWith(color: colors.surface),
            ),
          ],
        ),
      ),
    );
  }
}
