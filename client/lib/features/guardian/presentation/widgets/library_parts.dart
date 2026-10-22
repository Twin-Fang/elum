import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/assets/app_assets.dart';
import '../../../../core/l10n/l10n_context.dart';
import '../../../../core/layout/layout_context_ext.dart';
import '../../../../core/layout/window_size_class.dart';
import '../../../../core/router/routes.dart';
import '../../../../core/theme/theme_context_ext.dart';
import '../../../../core/widgets/app_pressable.dart';
import '../../../../core/widgets/character_badge.dart';
import '../../../../core/widgets/elum_floating_pill_button.dart';
import '../../../../core/widgets/elum_spinner.dart';
import '../../application/guardian_child_identity.dart';
import '../../application/routine_manage_coach_notifier.dart';
import 'coach_help_button.dart';

// 일과관리 칸 화면 조각: 머리, 빈 상태, `+ 일과 만들기` 버튼 (#805). 격자는 library_entry_grid.dart

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
          // 제목 + 사용법(코치마크) 다시 보기 `?` — 배지는 오른쪽 끝에 붙는다
          Expanded(
            child: Row(
              children: [
                Flexible(
                  child: Text(
                    context.l10n.guardianTabManage,
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

/// 원본이 하나도 없을 때 (불러오는 중·실패와 구분되는 빈 상태)
class LibraryEmptyState extends StatelessWidget {
  const LibraryEmptyState({required this.bottomSpace});

  final double bottomSpace;

  /// 루미 일러스트 한 변 (정사각형, 여백 포함)
  static const _illustrationSize = 220.0;

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
            Image.asset(
              AppAssets.routinesEmptyLumi,
              width: _illustrationSize.w,
              height: _illustrationSize.w,
              // 장식 그림 (제목이 뜻을 전한다)
              excludeFromSemantics: true,
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
