import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/l10n/l10n_context.dart';
import '../../../../core/router/routes.dart';
import '../../../../core/widgets/elum_scaffold.dart';
import '../../../../core/widgets/settings_group.dart';
import '../../../../core/widgets/settings_tile.dart';
import '../../domain/guide_tip.dart';
import '../widgets/guide_tip_card.dart';

/// 보호자 가이드 목록 (설정 > 약관 및 정보): 가이드 5개 > 누르면 앱 안 읽기 (홈 팁을 닫은 뒤에도 다시 보는 자리, #1455)
class GuideListScreen extends StatelessWidget {
  const GuideListScreen({super.key});

  /// 머리 고정 영역 아래 · 첫 묶음 위 (약관 목록과 같은 리듬)
  static const _listTop = 24.0;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return ElumScaffold(
      onBack: () => Navigator.of(context).maybePop(),
      title: l10n.guardianSettingsGuides,
      backTop: ElumScaffold.settingsBackTop,
      horizontalPadding: 16,
      child: SingleChildScrollView(
        padding: EdgeInsets.only(top: _listTop.h),
        child: SettingsGroup(
          children: [
            for (final tip in GuideTip.values)
              SettingsTile(
                isInCard: true,
                label: GuideTipSlot.titleOf(tip, l10n),
                onTap: () => context.push(Routes.guardianGuideArticleOf(tip.slug)),
              ),
          ],
        ),
      ),
    );
  }
}
