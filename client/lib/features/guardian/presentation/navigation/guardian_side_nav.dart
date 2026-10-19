import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/assets/app_assets.dart';
import '../../../../core/l10n/l10n_context.dart';
import '../../../../core/router/routes.dart';
import '../../../../core/theme/theme_context_ext.dart';
import '../../../../core/widgets/app_pressable.dart';
import '../../../../core/widgets/character_badge.dart';
import '../../application/guardian_child_identity.dart';
import '../../../notification/presentation/widgets/notification_bell_button.dart';
import 'guardian_bottom_nav.dart';
import 'guardian_tab.dart';
import 'guardian_tab_icon.dart';

/// 태블릿 보호자 옆 메뉴: 로고 · 이룸이 카드 · 칸 4개 · 맨 아래 이룸이 화면 (#798 시안 T3)
///
/// 항상 펼쳐 둔다. 이룸이 화면으로 가는 입구가 여기 있어 홈 오른쪽 위 배지는 태블릿에서 빠진다.
class GuardianSideNav extends ConsumerWidget {
  const GuardianSideNav({
    super.key,
    required this.selectedTab,
    required this.onTabSelected,
  });

  final GuardianTab selectedTab;
  final ValueChanged<GuardianTab> onTabSelected;

  /// 메뉴 폭 (시안 196~208)
  static const width = 208.0;

  /// 로고 30 높이 · 이룸이 카드 배지 40 · 칸 아이콘 24
  static const _logoHeight = 30.0;
  static const _logoWidth = 80.0;
  static const _badgeSize = 40.0;
  static const _itemIconSize = 24.0;
  static const _itemRadius = 14.0;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final space = context.space;
    final identity = ref.watch(guardianChildIdentityProvider);
    final padding = MediaQuery.paddingOf(context);

    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.navBackground,
        border: Border(
          right: BorderSide(
            color: colors.navDivider,
            width: GuardianBottomNav.dividerWidth,
          ),
        ),
      ),
      child: SizedBox(
        width: width.w + padding.left,
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            padding.left + space.sm.w,
            padding.top + space.lg.h,
            space.sm.w,
            padding.bottom + space.md.h,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 로고(왼쪽) + 종 아이콘(오른쪽 끝)
              Padding(
                padding: EdgeInsets.symmetric(horizontal: space.sm.w),
                child: Row(
                  children: [
                    SvgPicture.asset(
                      AppAssets.homeLogo,
                      width: _logoWidth.w,
                      height: _logoHeight.h,
                    ),
                    const Spacer(),
                    const NotificationBellButton(),
                  ],
                ),
              ),
              SizedBox(height: space.md.h),
              // 누구의 보호자 화면인지
              _ChildCard(identity: identity),
              SizedBox(height: space.md.h),
              // 칸 4개
              for (final tab in GuardianTab.values)
                _SideNavItem(
                  tab: tab,
                  isSelected: tab == selectedTab,
                  onTap: () => onTabSelected(tab),
                ),
              const Spacer(),
              // 이룸이 화면 입구 (보호자 > 이룸이 방향은 암호 없이 바로 간다)
              _ChildScreenButton(identity: identity),
            ],
          ),
        ),
      ),
    );
  }
}

/// 이룸이 카드: 캐릭터 배지 + 이름 + `보호자 화면`
class _ChildCard extends StatelessWidget {
  const _ChildCard({required this.identity});

  final GuardianChildIdentity identity;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final space = context.space;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(GuardianSideNav._itemRadius.w),
      ),
      child: Padding(
        padding: EdgeInsets.all(space.xs.w),
        child: Row(
          children: [
            // 보호자 화면 카드: 이룸이 캐릭터가 아니라 루미
            Image.asset(
              AppAssets.guardianProfileLumi,
              width: GuardianSideNav._badgeSize.w,
              height: GuardianSideNav._badgeSize.w,
            ),
            SizedBox(width: space.xs.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    identity.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: context.typo.tileLabel.copyWith(
                      color: colors.textPrimary,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  Text(
                    context.l10n.guardianSideNavCaption,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: context.typo.caption.copyWith(
                      color: colors.textSecondary,
                    ),
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

/// 옆 메뉴 칸 하나: 아이콘 + 이름, 고른 칸은 연한 보라 바탕
class _SideNavItem extends StatelessWidget {
  const _SideNavItem({
    required this.tab,
    required this.isSelected,
    required this.onTap,
  });

  final GuardianTab tab;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final space = context.space;
    final color = isSelected
        ? colors.navIconSelected
        : colors.navItemUnselected;
    return Semantics(
      selected: isSelected,
      button: true,
      child: AppPressable(
        onTap: onTap,
        scaleDown: AppPressable.scaleCard,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: isSelected ? colors.navSelectedFill : null,
            borderRadius: BorderRadius.circular(GuardianSideNav._itemRadius.w),
          ),
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: space.sm.w,
              vertical: space.sm.h,
            ),
            child: Row(
              children: [
                GuardianTabIcon(
                  tab: tab,
                  size: GuardianSideNav._itemIconSize.w,
                  color: color,
                ),
                SizedBox(width: space.sm.w),
                Expanded(
                  child: Text(
                    tab.labelOf(context),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: context.typo.tileLabel.copyWith(
                      color: color,
                      fontWeight: isSelected ? FontWeight.w800 : null,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// 맨 아래 `이룸이 화면` 버튼
class _ChildScreenButton extends StatelessWidget {
  const _ChildScreenButton({required this.identity});

  final GuardianChildIdentity identity;

  /// 버튼 안 배지 한 변
  static const _badgeSize = 28.0;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final space = context.space;
    return AppPressable(
      onTap: () => context.go(Routes.child),
      semanticLabel: context.l10n.guardianHomeGoChildScreen,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: colors.navSelectedFill,
          borderRadius: BorderRadius.circular(GuardianSideNav._itemRadius.w),
        ),
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: space.sm.w,
            vertical: space.xs.h,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _SmallBadge(identity: identity, size: _badgeSize),
              SizedBox(width: space.xs.w),
              Flexible(
                child: Text(
                  context.l10n.guardianSideNavChildScreen,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: context.typo.tileLabel.copyWith(
                    color: colors.navIconSelected,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 캐릭터 배지를 원하는 크기로 줄여 그린다 (배지 원본은 56 고정)
class _SmallBadge extends StatelessWidget {
  const _SmallBadge({required this.identity, required this.size});

  final GuardianChildIdentity identity;
  final double size;

  @override
  Widget build(BuildContext context) {
    // 정사각형 — 가로세로 모두 .w
    return SizedBox.square(
      dimension: size.w,
      child: FittedBox(child: CharacterBadge(character: identity.character)),
    );
  }
}
