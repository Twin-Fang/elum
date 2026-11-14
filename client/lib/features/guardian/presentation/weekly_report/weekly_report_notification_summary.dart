import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../core/assets/app_assets.dart';
import '../../../../core/l10n/l10n_context.dart';
import '../../../../core/theme/theme_context_ext.dart';
import '../../../../core/widgets/elum_info_card.dart';
import '../../../../core/widgets/elum_secondary_button.dart';
import '../../../../core/widgets/elum_state_body.dart';
import '../../application/weekly_report_providers.dart';
import '../../domain/weekly_report.dart';

/// 알림으로 들어온 Free 보호자 요약 (판매 판을 바로 띄우지 않음): 3D 그림 + 제목 + 그 주에 마친 일과 수 + (살 수 있으면) 조용한 `Pro 로 자세히 보기`
/// 마친 수는 권한 없이 받는 주 목록에서 읽음. 목록에 없는 주 · 받기 실패면 숫자 없는 한 줄
class WeeklyReportNotificationSummary extends ConsumerWidget {
  const WeeklyReportNotificationSummary({super.key, required this.weekStart, required this.onSeeDetails});

  /// 알림의 주 (월요일)
  final DateTime weekStart;

  /// `Pro 로 자세히 보기` (null 이면 버튼 없음: 판매 꺼짐)
  final VoidCallback? onSeeDetails;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final weeksAsync = ref.watch(weeklyReportWeeksProvider);
    if (weeksAsync.isLoading && !weeksAsync.hasValue) return const ElumStateBody.loading();
    final completedCount = weeksAsync.value?.weeks
        .where((entry) => weekStartOf(entry.weekStart) == weekStart)
        .firstOrNull
        ?.completedRoutineCount;
    final l10n = context.l10n;
    final onSeeDetails = this.onSeeDetails;
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ElumInfoCard(
            layout: ElumInfoCardLayout.top,
            illustrationAsset: AppAssets.featureIconWeeklyReport,
            title: l10n.weeklyReportNotificationTitle,
            body: completedCount != null && completedCount > 0
                ? l10n.weeklyReportNotificationCompleted(completedCount)
                : l10n.weeklyReportNotificationNoCount,
          ),
          if (onSeeDetails != null) ...[
            SizedBox(height: context.space.md.h),
            ElumSecondaryButton(label: l10n.weeklyReportNotificationProDetail, onTap: onSeeDetails),
          ],
        ],
      ),
    );
  }
}
