import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../../core/theme/theme_context_ext.dart';
import '../../../../core/widgets/app_pressable.dart';
import '../../../../core/widgets/min_tap_target.dart';

/// 돌아보기 카드 한 장의 판: 강조색 원 아이콘 + 제목 줄 > 문장 > (작은 글) > (아래 내용)
class WeeklyReportInsightPlate extends StatelessWidget {
  const WeeklyReportInsightPlate({
    super.key,
    required this.fill,
    required this.accent,
    required this.iconAsset,
    required this.title,
    required this.line,
    this.hint,
    this.child,
  });

  final Color fill;
  final Color accent;
  final String iconAsset;
  final String title;
  final String line;

  /// 문장 아래 작은 글
  final String? hint;

  /// 작은 글 아래 내용 (버튼 · 막대)
  final Widget? child;

  static const _padding = 20.0;
  static const _iconCircleSize = 28.0;
  static const _iconSize = 16.0;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final space = context.space;
    final hint = this.hint;
    final child = this.child;
    return DecoratedBox(
      decoration: BoxDecoration(color: fill, borderRadius: BorderRadius.circular(space.cardRadius.r)),
      child: Padding(
        padding: EdgeInsets.all(_padding.w),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                DecoratedBox(
                  decoration: BoxDecoration(color: accent, shape: BoxShape.circle),
                  child: SizedBox(
                    width: _iconCircleSize.w,
                    height: _iconCircleSize.w,
                    child: Center(
                      child: SvgPicture.asset(
                        iconAsset,
                        width: _iconSize.w,
                        height: _iconSize.w,
                        excludeFromSemantics: true,
                        colorFilter: ColorFilter.mode(colors.surface, BlendMode.srcIn),
                      ),
                    ),
                  ),
                ),
                SizedBox(width: space.xs.w),
                Expanded(
                  child: Text(title, style: context.typo.settingsGroupLabel.copyWith(color: accent)),
                ),
              ],
            ),
            SizedBox(height: space.sm.h),
            Text(line, style: context.typo.creditHistoryRowTitle.copyWith(color: colors.textPrimary, height: 1.4)),
            if (hint != null) ...[
              SizedBox(height: space.xs.h),
              Text(hint, style: context.typo.creditBody.copyWith(color: colors.textSecondary)),
            ],
            if (child != null) ...[SizedBox(height: space.sm.h), child],
          ],
        ),
      ),
    );
  }
}

/// 판 안의 어두운 알약 버튼 (`양치하기 카드 고치기`)
class WeeklyReportInsightButton extends StatelessWidget {
  const WeeklyReportInsightButton({super.key, required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  static const _padHorizontal = 16.0;
  static const _padVertical = 10.0;
  static const _radius = 100.0;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Align(
      alignment: Alignment.centerLeft,
      child: MinTapTarget(
        child: AppPressable(
          onTap: onTap,
          child: DecoratedBox(
            decoration: BoxDecoration(color: colors.textPrimary, borderRadius: BorderRadius.circular(_radius.r)),
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: _padHorizontal.w, vertical: _padVertical.h),
              child: Text(label, style: context.typo.chipLabel.copyWith(color: colors.surface)),
            ),
          ),
        ),
      ),
    );
  }
}

/// 지난주 · 이번 주 두 막대 (높이는 큰 쪽을 기준으로 비례, 낮아도 보이게 하한)
class WeeklyReportTrendBars extends StatelessWidget {
  const WeeklyReportTrendBars({
    super.key,
    required this.previousCount,
    required this.currentCount,
    required this.previousLabel,
    required this.currentLabel,
    required this.currentColor,
  });

  final int previousCount;
  final int currentCount;
  final String previousLabel;
  final String currentLabel;
  final Color currentColor;

  static const _barWidth = 44.0;
  static const _barAreaHeight = 56.0;
  static const _barRadius = 8.0;
  static const _minHeightFactor = 0.15;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final largest = [previousCount, currentCount, 1].reduce((a, b) => a > b ? a : b);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        _bar(context, label: previousLabel, count: previousCount, largest: largest, color: colors.buttonNeutral),
        SizedBox(width: context.space.sm.w),
        _bar(context, label: currentLabel, count: currentCount, largest: largest, color: currentColor),
      ],
    );
  }

  Widget _bar(
    BuildContext context, {
    required String label,
    required int count,
    required int largest,
    required Color color,
  }) {
    final heightFactor = (count / largest).clamp(_minHeightFactor, 1.0);
    return Column(
      children: [
        SizedBox(
          width: _barWidth.w,
          height: _barAreaHeight.h,
          child: Align(
            alignment: Alignment.bottomCenter,
            child: FractionallySizedBox(
              heightFactor: heightFactor,
              widthFactor: 1,
              child: DecoratedBox(
                decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(_barRadius.r)),
              ),
            ),
          ),
        ),
        SizedBox(height: context.space.xs.h / 2),
        Text(label, style: context.typo.creditCaption.copyWith(color: context.colors.textSecondary)),
      ],
    );
  }
}
