import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/assets/app_assets.dart';
import '../../../../core/l10n/l10n_context.dart';
import '../../../../core/router/routes.dart';
import '../../../../core/theme/theme_context_ext.dart';
import '../../../../core/widgets/app_pressable.dart';
import '../../../../core/widgets/min_tap_target.dart';
import '../../domain/credit_breakdown.dart';
import '../../domain/credit_period_unit.dart';
import '../../domain/credit_summary.dart';
import 'my_credit_kind_labels.dart';

/// 내 크레딧 위 카드: 크레딧 그림 + 지금 쓸 수 있는 개수 + `쓴 내역` > 종류별 색 게이지 > 종류마다 한 줄
///
/// 가진 종류만 줄이 생긴다. 게이지 조각 길이는 남은 개수 비율 (남은 게 없으면 빈 막대)
class MyCreditBalanceCard extends StatelessWidget {
  const MyCreditBalanceCard({super.key, required this.summary});

  final CreditSummary summary;

  static const _padding = 20.0;
  static const _pictureSize = 44.0;
  static const _gaugeHeight = 8.0;
  static const _gaugeGap = 4.0;
  static const _linePictureSize = 24.0;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final space = context.space;
    final lines = summary.breakdownLines;
    return DecoratedBox(
      decoration: BoxDecoration(color: colors.surface, borderRadius: BorderRadius.circular(space.cardRadius.r)),
      child: Padding(
        padding: EdgeInsets.all(_padding.w),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Image.asset(AppAssets.creditTicket, width: _pictureSize.w, excludeFromSemantics: true),
                SizedBox(width: space.sm.w),
                Flexible(
                  child: Text.rich(
                    TextSpan(
                      children: [
                        TextSpan(text: '${summary.available}', style: context.typo.creditNumber),
                        TextSpan(text: ' ${context.l10n.myCreditCountUnit}', style: context.typo.creditUnit),
                      ],
                    ),
                    style: TextStyle(color: colors.textPrimary),
                  ),
                ),
                const Spacer(),
                _HistoryButton(),
              ],
            ),
            SizedBox(height: space.md.h),
            _Gauge(lines: lines),
            SizedBox(height: space.sm.h),
            for (final line in lines) _LineRow(line: line, periodUnit: summary.periodUnit),
          ],
        ),
      ),
    );
  }
}

/// `쓴 내역 ›` 알약: 크레딧 사용 내역 화면으로
class _HistoryButton extends StatelessWidget {
  static const _padH = 12.0;
  static const _padV = 6.0;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return MinTapTarget(
      child: AppPressable(
        onTap: () => context.push(Routes.guardianCreditHistory),
        child: DecoratedBox(
          decoration: BoxDecoration(color: colors.buttonNeutral, borderRadius: BorderRadius.circular(context.space.pillRadius.r)),
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: _padH.w, vertical: _padV.h),
            child: Text(
              '${context.l10n.myCreditHistoryButton} ›',
              style: context.typo.chipLabel.copyWith(color: colors.buttonNeutralText),
            ),
          ),
        ),
      ),
    );
  }
}

/// 종류별 색을 이어 붙인 게이지
class _Gauge extends StatelessWidget {
  const _Gauge({required this.lines});

  final List<CreditBreakdownLine> lines;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final segments = [for (final line in lines) if (line.remaining > 0) line];
    final radius = BorderRadius.circular(MyCreditBalanceCard._gaugeHeight.r);
    if (segments.isEmpty) {
      return SizedBox(
        height: MyCreditBalanceCard._gaugeHeight.h,
        child: DecoratedBox(decoration: BoxDecoration(color: colors.creditBarTrack, borderRadius: radius)),
      );
    }
    return SizedBox(
      height: MyCreditBalanceCard._gaugeHeight.h,
      child: Row(
        children: [
          for (final (index, line) in segments.indexed) ...[
            if (index > 0) SizedBox(width: MyCreditBalanceCard._gaugeGap.w),
            Expanded(
              flex: line.remaining,
              child: DecoratedBox(decoration: BoxDecoration(color: line.colorOf(colors), borderRadius: radius)),
            ),
          ],
        ],
      ),
    );
  }
}

/// 종류 한 줄: 작은 그림, 이름, 끝나는 때, 남은 개수
class _LineRow extends StatelessWidget {
  const _LineRow({required this.line, required this.periodUnit});

  final CreditBreakdownLine line;
  final CreditPeriodUnit periodUnit;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final l10n = context.l10n;
    return Padding(
      padding: EdgeInsets.symmetric(vertical: context.space.xs.h / 2),
      child: Row(
        children: [
          Image.asset(line.pictureAsset, width: MyCreditBalanceCard._linePictureSize.w, excludeFromSemantics: true),
          SizedBox(width: context.space.xs.w),
          Text(line.kindName(l10n, periodUnit), style: context.typo.creditTitle.copyWith(color: colors.textPrimary)),
          SizedBox(width: context.space.xs.w),
          Expanded(
            child: Text(
              line.endLabel(l10n, periodUnit),
              style: context.typo.creditCaption.copyWith(color: colors.creditMutedText),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Text('${line.remaining}', style: context.typo.creditTitle.copyWith(color: colors.textPrimary)),
        ],
      ),
    );
  }
}
