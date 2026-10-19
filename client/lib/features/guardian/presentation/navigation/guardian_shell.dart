import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/layout/layout_context_ext.dart';
import '../../../../core/layout/window_size_class.dart';
import '../../../../core/theme/theme_context_ext.dart';
import '../../application/routine_providers.dart';
import 'guardian_bottom_nav.dart';
import 'guardian_side_nav.dart';
import 'guardian_tab.dart';

/// 보호자 화면 틀: 칸 4개를 담고 창 크기에 따라 이동 막대를 고른다 (#798)
///
/// 폰(compact) = 본문 > 하단 바 > 광고 띠, 태블릿(medium·expanded) = 옆 메뉴 | 본문 > 광고 띠.
/// 칸마다 화면 상태(스크롤 등)는 라우터의 가지가 지킨다.
class GuardianShell extends StatelessWidget {
  const GuardianShell({
    super.key,
    required this.navigationShell,
    required this.adStrip,
  });

  final StatefulNavigationShell navigationShell;

  /// 맨 아래 광고 띠. 다른 기능(광고)의 화면이라 라우터가 넣어 준다
  final Widget adStrip;

  GuardianTab get _currentTab =>
      GuardianTab.values[navigationShell.currentIndex];

  /// 칸 이동: 지금 칸을 다시 누르면 그 칸의 첫 화면으로 돌아간다
  void _selectTab(GuardianTab tab) {
    navigationShell.goBranch(
      tab.index,
      initialLocation: tab.index == navigationShell.currentIndex,
    );
  }

  @override
  Widget build(BuildContext context) {
    final adStripGate = _AdStripGate(tab: _currentTab, adStrip: adStrip);
    return context.sizeClass == WindowSizeClass.compact
        ? _buildPhone(context, adStripGate)
        : _buildTablet(context, adStripGate);
  }

  /// 폰: 본문 > 하단 바 > 광고 띠 > 홈 표시줄 여백
  Widget _buildPhone(BuildContext context, Widget adStripGate) {
    final colors = context.colors;
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    return Scaffold(
      backgroundColor: colors.background,
      body: Column(
        children: [
          // 아래 안전영역은 이 틀이 맡는다 — 칸 화면이 또 비우면 바 위에 빈 띠가 생긴다
          Expanded(
            child: MediaQuery.removePadding(
              context: context,
              removeBottom: true,
              child: _ContentSemanticsScope(child: navigationShell),
            ),
          ),
          GuardianBottomNav(
            selectedTab: _currentTab,
            onTabSelected: _selectTab,
          ),
          adStripGate,
          ColoredBox(
            color: colors.navBackground,
            child: SizedBox(height: bottomInset, width: double.infinity),
          ),
        ],
      ),
    );
  }

  /// 태블릿: 옆 메뉴 | (본문 > 광고 띠 > 홈 표시줄 여백)
  Widget _buildTablet(BuildContext context, Widget adStripGate) {
    final colors = context.colors;
    final media = MediaQuery.of(context);
    return Scaffold(
      backgroundColor: colors.background,
      body: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          GuardianSideNav(selectedTab: _currentTab, onTabSelected: _selectTab),
          Expanded(
            child: Column(
              children: [
                Expanded(
                  // 본문 크기 = 옆 메뉴를 뺀 칸. 칸 화면의 가운데 열·두 칸 판단이 이 폭을 쓴다
                  child: LayoutBuilder(
                    builder: (context, constraints) => MediaQuery(
                      data: media.copyWith(
                        size: constraints.biggest,
                        // 왼쪽은 옆 메뉴가, 아래는 이 틀이 맡는다
                        padding: media.padding.copyWith(left: 0, bottom: 0),
                        viewPadding: media.viewPadding.copyWith(
                          left: 0,
                          bottom: 0,
                        ),
                      ),
                      child: _ContentSemanticsScope(child: navigationShell),
                    ),
                  ),
                ),
                adStripGate,
                SizedBox(height: media.padding.bottom),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// 광고 띠를 둘지 정하는 자리: 일과가 충분할 때만, 내정보 칸은 제외 (로드 전·실패 시 높이 0)
///
/// 값이 바뀌면 **다음 프레임에** 다시 그린다. 흐름 화면에서 돌아와 목록을 다시 받는 순간 값이 빌드 도중에
/// 바뀌면 `markNeedsBuild() called during build` 가 나기 때문이다.
class _AdStripGate extends ConsumerStatefulWidget {
  const _AdStripGate({required this.tab, required this.adStrip});

  final GuardianTab tab;
  final Widget adStrip;

  @override
  ConsumerState<_AdStripGate> createState() => _AdStripGateState();
}

class _AdStripGateState extends ConsumerState<_AdStripGate> {
  late bool _isEnoughRoutines = ref.read(shouldShowHomeAdsProvider);

  @override
  void initState() {
    super.initState();
    ref.listenManual<bool>(shouldShowHomeAdsProvider, (_, next) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && next != _isEnoughRoutines) {
          setState(() => _isEnoughRoutines = next);
        }
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final isVisible = widget.tab.isAdStripAllowed && _isEnoughRoutines;
    return isVisible ? widget.adStrip : const SizedBox.shrink();
  }
}

/// 칸 화면을 따로 낭독 묶음 · 알림 자리로 가둔다
///
/// 칸 화면의 내비게이터(라우트 막)가 같은 묶음에서 먼저 그려진 것의 낭독 정보를 지운다.
/// 옆 메뉴는 본문보다 먼저 그려지므로 가두지 않으면 화면 낭독기에서 옆 메뉴가 통째로 사라진다.
class _ContentSemanticsScope extends StatelessWidget {
  const _ContentSemanticsScope({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => Semantics(
    container: true,
    explicitChildNodes: true,
    // 칸 화면의 알림(토스트)도 본문 안에서 뜨게 — 창 가운데에 뜨면 태블릿 옆 메뉴를 덮는다
    child: ScaffoldMessenger(child: child),
  );
}
