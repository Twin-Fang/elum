import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../core/theme/theme_context_ext.dart';

/// 그래프 흰 판 (r20): 작은 제목 > 그래프. 요약 도넛·요일별·주별 추이가 함께 쓴다
class WeeklyReportChartCard extends StatelessWidget {
  const WeeklyReportChartCard({super.key, required this.child, this.title});

  /// null 이면 제목 줄 없이 그래프만
  final String? title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final title = this.title;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: context.colors.settingsGroupBg,
        borderRadius: BorderRadius.circular(context.space.cardRadius.r),
      ),
      child: Padding(
        padding: EdgeInsets.all(context.space.md.w),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (title != null) ...[
              Text(title, style: context.typo.settingsGroupLabel.copyWith(color: context.colors.settingsGroupLabel)),
              SizedBox(height: context.space.sm.h),
            ],
            child,
          ],
        ),
      ),
    );
  }
}
