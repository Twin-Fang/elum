import 'package:flutter/material.dart';

import '../../../../core/assets/app_assets.dart';
import '../../../../core/l10n/l10n_context.dart';
import '../../../../core/router/routes.dart';

/// 보호자 화면 칸 4개: 홈 · 일과 관리 · 이야기 · 내 정보 (#798, 아이콘·이름 시안 #835)
///
/// 칸 순서·경로·아이콘·이름의 단일 원본. 라우터 가지 순서, 하단 바, 옆 메뉴가 모두 이 순서를 따른다.
/// 칸을 더하면 여기 값 하나와 라우터 가지 하나만 늘린다.
enum GuardianTab {
  home(path: Routes.guardian, iconAsset: AppAssets.navHome),
  manage(path: Routes.guardianManage, iconAsset: AppAssets.navFolder),
  talk(path: Routes.guardianTalk, iconAsset: AppAssets.navComment),
  me(path: Routes.guardianMyInfo, iconAsset: AppAssets.navUser);

  const GuardianTab({required this.path, required this.iconAsset});

  /// 이 칸의 첫 화면 경로
  final String path;

  /// 칸 아이콘 (시안 SVG, #835). 고른 칸 · 아닌 칸은 같은 모양에 색만 다르다
  final String iconAsset;

  /// 칸 이름. 폰 하단 바 · 태블릿 옆 메뉴의 보이는 글자이자 화면 낭독 이름
  String labelOf(BuildContext context) => switch (this) {
    GuardianTab.home => context.l10n.guardianTabHome,
    GuardianTab.manage => context.l10n.guardianTabManage,
    GuardianTab.talk => context.l10n.guardianTabTalk,
    GuardianTab.me => context.l10n.guardianTabMe,
  };
}
