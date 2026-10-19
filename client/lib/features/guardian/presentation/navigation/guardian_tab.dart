import 'package:flutter/material.dart';

import '../../../../core/l10n/l10n_context.dart';
import '../../../../core/router/routes.dart';

/// 보호자 화면 칸 4개: 홈 · 일과관리 · 이야기 · 내정보 (#798)
///
/// 칸 순서·경로·아이콘·이름의 단일 원본. 라우터 가지 순서, 하단 바, 옆 메뉴가 모두 이 순서를 따른다.
/// 칸을 더하면 여기 값 하나와 라우터 가지 하나만 늘린다.
enum GuardianTab {
  home(
    path: Routes.guardian,
    icon: Icons.home_outlined,
    selectedIcon: Icons.home_rounded,
  ),
  manage(
    path: Routes.guardianManage,
    icon: Icons.folder_outlined,
    selectedIcon: Icons.folder_rounded,
  ),
  talk(
    path: Routes.guardianTalk,
    icon: Icons.chat_bubble_outline_rounded,
    selectedIcon: Icons.chat_bubble_rounded,
  ),
  me(
    path: Routes.guardianSettings,
    icon: Icons.person_outline_rounded,
    selectedIcon: Icons.person_rounded,
  );

  const GuardianTab({
    required this.path,
    required this.icon,
    required this.selectedIcon,
  });

  /// 이 칸의 첫 화면 경로
  final String path;

  /// 고르지 않은 칸 (선 아이콘) <-> 고른 칸 (꽉 찬 아이콘)
  final IconData icon;
  final IconData selectedIcon;

  /// 칸 이름. 폰 하단 바에서는 화면 낭독 이름, 태블릿 옆 메뉴에서는 보이는 글자
  String labelOf(BuildContext context) => switch (this) {
    GuardianTab.home => context.l10n.guardianTabHome,
    GuardianTab.manage => context.l10n.guardianTabManage,
    GuardianTab.talk => context.l10n.guardianTabTalk,
    GuardianTab.me => context.l10n.guardianTabMe,
  };

  /// 아래 광고 띠를 둘 칸인가
  ///
  /// 내정보(설정)는 맨 아래 `회원탈퇴` 줄과 가까워 광고를 잘못 누르면 되돌릴 수 없는 동작으로 이어질 수 있다
  bool get isAdStripAllowed => this != GuardianTab.me;
}
