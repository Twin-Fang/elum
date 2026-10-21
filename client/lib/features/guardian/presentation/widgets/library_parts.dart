import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/assets/app_assets.dart';
import '../../../../core/l10n/l10n_context.dart';
import '../../../../core/layout/layout_context_ext.dart';
import '../../../../core/layout/window_size_class.dart';
import '../../../../core/router/routes.dart';
import '../../../../core/theme/theme_context_ext.dart';
import '../../../../core/widgets/app_pressable.dart';
import '../../../../core/widgets/character_badge.dart';
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

  /// 버튼 높이 · 하단 바와의 간격 (시안: 58, 하단 바 위 32)
  static const height = 58.0;
  static const navGap = 32.0;

  /// 격자가 버튼 아래로 숨지 않게 남길 아래 여백 (버튼 + 간격 + 버튼 위 숨 16)
  static const scrollBottomSpace = height + navGap + 16;

  /// 버튼 자리: 가운데 아래, 하단 바 위 [navGap]
  static const FloatingActionButtonLocation location = _CreateButtonLocation();

  /// 더하기 아이콘 한 변 · 글자 좌우 여백 (시안: 폭 177 = 37.5 + 아이콘 16 + 8 + 글자 + 37.5)
  static const _iconSize = 16.0;
  static const _horizontalPadding = 37.5;

  /// 그림자 (#242634 25%, 아래 4, 흐림 20)
  static const _shadowAlpha = 0.25;
  static const _shadowBlur = 20.0;
  static const _shadowOffsetY = 4.0;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final space = context.space;
    final scaledHeight = height.h;
    return AppPressable(
      onTap: isBusy ? null : onTap,
      child: Container(
        height: scaledHeight,
        padding: EdgeInsets.symmetric(horizontal: _horizontalPadding.w),
        decoration: BoxDecoration(
          color: colors.textPrimary,
          borderRadius: BorderRadius.circular(scaledHeight / 2),
          boxShadow: [
            BoxShadow(
              color: colors.textPrimary.withValues(alpha: _shadowAlpha),
              blurRadius: _shadowBlur,
              offset: Offset(0, _shadowOffsetY.h),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isBusy)
              ElumSpinner(size: _iconSize.w, color: colors.surface)
            else if (!isArranging)
              SvgPicture.asset(
                AppAssets.iconPlus,
                width: _iconSize.w,
                height: _iconSize.w,
                colorFilter: ColorFilter.mode(colors.surface, BlendMode.srcIn),
              ),
            if (!isArranging) SizedBox(width: space.xs.w),
            Text(
              isArranging
                  ? context.l10n.libraryArrangeDone
                  : context.l10n.routineLibraryCreate,
              style: context.typo.libraryCreateLabel.copyWith(
                color: colors.surface,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 가운데 아래 버튼 자리: 기본 centerFloat(바닥 위 16)에서 [CreateRoutineFab.navGap] 까지 올린다
class _CreateButtonLocation extends StandardFabLocation
    with FabCenterOffsetX, FabFloatOffsetY {
  const _CreateButtonLocation();

  @override
  double getOffsetY(
    ScaffoldPrelayoutGeometry scaffoldGeometry,
    double adjustment,
  ) =>
      super.getOffsetY(scaffoldGeometry, adjustment) -
      (CreateRoutineFab.navGap - kFloatingActionButtonMargin).h;
}
