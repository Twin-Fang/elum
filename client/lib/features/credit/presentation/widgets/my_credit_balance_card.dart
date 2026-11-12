import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../../core/assets/app_assets.dart';
import '../../../../core/l10n/l10n_context.dart';
import '../../../../core/theme/theme_context_ext.dart';
import '../../../../core/widgets/ai_credit_bar.dart';
import '../../../../core/widgets/elum_guide_panel.dart';
import '../../../member/application/plan_access.dart';
import '../../domain/credit_breakdown.dart';
import '../../domain/credit_period_unit.dart';
import '../../domain/credit_summary.dart';
import 'my_credit_kind_labels.dart';

/// 내 크레딧 위 카드 하나: 표 그림 + `N개 남았어요` > 남은 비율 막대 > 다시 채워지는 때 > 아래 칸 (#1300)
/// 아래 칸 2개 (있을 때만, 구분선 아래): 종류별 개수 (0 아닌 종류가 2개 이상) · Pro 오늘 다시 그리기 칩 (서버 하루 한도를 받았을 때)
class MyCreditBalanceCard extends ConsumerWidget {
  const MyCreditBalanceCard({super.key, required this.summary});

  final CreditSummary summary;

  static const _padding = 20.0;
  static const _pictureSize = 44.0;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final space = context.space;
    final l10n = context.l10n;
    final canRegenerateImagesFree = ref.watch(planAccessProvider.select((access) => access.canRegenerateImagesFree));
    final dailyCap = summary.freeImageRegenerateDailyCap;
    final shouldShowRedrawChip = canRegenerateImagesFree && dailyCap > 0;
    final heldLines = [for (final line in summary.breakdownLines) if (line.remaining > 0) line];
    // 종류가 하나뿐이면 큰 숫자와 같은 값이라 숨김
    final shouldShowBreakdown = heldLines.length > 1;
    return DecoratedBox(
      decoration: BoxDecoration(color: colors.surface, borderRadius: BorderRadius.circular(space.cardRadius.r)),
      child: Padding(
        padding: EdgeInsets.all(_padding.w),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 표 그림 + 큰 숫자 + `개 남았어요` (숫자와 뒷말은 한 글줄이라 기준선이 맞음)
            Row(
              children: [
                Image.asset(AppAssets.creditTicket, width: _pictureSize.w, excludeFromSemantics: true),
                SizedBox(width: space.sm.w),
                Flexible(
                  child: Text.rich(
                    TextSpan(
                      children: [
                        TextSpan(text: '${summary.available}', style: context.typo.creditNumber),
                        TextSpan(text: l10n.myCreditRemainingSuffix, style: context.typo.creditTitle),
                      ],
                    ),
                    style: TextStyle(color: colors.textPrimary),
                  ),
                ),
              ],
            ),
            SizedBox(height: space.md.h),
            AiCreditBar(ratio: summary.remainingRatio, color: colors.creditBarFill),
            SizedBox(height: space.xs.h),
            Text(
              l10n.aiCreditResetLine(summary.resetLabel),
              style: context.typo.creditReset.copyWith(color: colors.creditMutedText),
            ),
            if (shouldShowBreakdown || shouldShowRedrawChip) ...[
              SizedBox(height: space.xs.h),
              const ElumGuideDivider(),
              SizedBox(height: space.xs.h),
            ],
            if (shouldShowBreakdown)
              Wrap(
                spacing: space.md.w,
                runSpacing: space.xs.h,
                children: [
                  for (final line in heldLines) _KindCount(line: line, periodUnit: summary.periodUnit),
                ],
              ),
            if (shouldShowBreakdown && shouldShowRedrawChip) SizedBox(height: space.sm.h),
            if (shouldShowRedrawChip)
              Align(
                alignment: Alignment.centerLeft,
                child: _FreeRedrawChip(label: l10n.myCreditFreeRegenerateToday(summary.freeImageRegeneratesLeftToday, dailyCap)),
              ),
          ],
        ),
      ),
    );
  }
}

/// 종류 하나: 작은 표 그림 + 이름 + 남은 개수 (`주간 100`)
class _KindCount extends StatelessWidget {
  const _KindCount({required this.line, required this.periodUnit});

  final CreditBreakdownLine line;
  final CreditPeriodUnit periodUnit;

  static const _pictureSize = 20.0;
  static const _pictureToLabel = 4.0;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Image.asset(line.pictureAsset, width: _pictureSize.w, excludeFromSemantics: true),
        SizedBox(width: _pictureToLabel.w),
        Text.rich(
          TextSpan(
            children: [
              TextSpan(
                text: '${line.kindName(context.l10n, periodUnit)} ',
                style: context.typo.creditBody.copyWith(color: colors.textSecondary),
              ),
              TextSpan(text: '${line.remaining}', style: context.typo.creditUnit.copyWith(color: colors.textPrimary)),
            ],
          ),
        ),
      ],
    );
  }
}

/// Pro 오늘 다시 그리기 칩: 돌림 아이콘 + `다시 그리기 오늘 N/M번 무료` (큰 글자면 칩 안에서 통째로 꺾임)
class _FreeRedrawChip extends StatelessWidget {
  const _FreeRedrawChip({required this.label});

  final String label;

  static const _padH = 10.0;
  static const _padV = 6.0;
  static const _iconSize = 14.0;
  static const _iconToLabel = 6.0;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    // 아이콘도 글자 배율을 따라 커짐 (큰 글자에서 점처럼 작아지지 않게)
    final iconSize = MediaQuery.textScalerOf(context).scale(_iconSize.w);
    return Container(
      padding: EdgeInsets.symmetric(horizontal: _padH.w, vertical: _padV.h),
      decoration: BoxDecoration(
        color: colors.creditNoticeBg,
        borderRadius: BorderRadius.circular(context.space.pillRadius.r),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SvgPicture.asset(
            AppAssets.iconRefresh,
            width: iconSize,
            height: iconSize,
            excludeFromSemantics: true,
            colorFilter: ColorFilter.mode(colors.textSecondary, BlendMode.srcIn),
          ),
          SizedBox(width: _iconToLabel.w),
          Flexible(
            child: Text(label, style: context.typo.chipLabel.copyWith(color: colors.textSecondary)),
          ),
        ],
      ),
    );
  }
}
