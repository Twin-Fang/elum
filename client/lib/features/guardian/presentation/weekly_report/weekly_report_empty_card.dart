import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/assets/app_assets.dart';
import '../../../../core/l10n/l10n_context.dart';
import '../../../../core/router/routes.dart';
import '../../../../core/widgets/elum_guide_panel.dart';
import 'weekly_report_chart_card.dart';

/// 기록이 없는 주의 빈 카드: 루미 > 제목 > 한 줄 > `일과 관리로 가기` (#1302)
///
/// 0만 가득한 숫자 칸 대신 다음에 할 일을 알려 준다. 보낸 일과 0건 · 끝낸 일과 0건 공통
class WeeklyReportEmptyCard extends StatelessWidget {
  const WeeklyReportEmptyCard({
    super.key,
    required this.title,
    required this.description,
  });

  final String title;
  final String description;

  @override
  Widget build(BuildContext context) => WeeklyReportChartCard(
    child: ElumGuidePanel(
      placement: ElumGuidePlacement.dialog,
      illustration: const ElumGuideIllustration(
        asset: AppAssets.notificationsEmptyLumi,
        size: ElumGuideIllustrationSize.dialog,
      ),
      title: title,
      description: description,
      primaryAction: ElumGuideAction(
        label: context.l10n.weeklyReportGoToManage,
        onTap: () => context.go(Routes.guardianManage),
      ),
    ),
  );
}
