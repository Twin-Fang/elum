import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../core/theme/theme_context_ext.dart';
import '../../../credit/domain/credit_summary.dart';
import 'ai_credit_card.dart';

/// 크레딧 카드 안의 내용 — 조회에 성공했을 때 (#407).
///
/// 정상 · 보너스 · 적음 · 0 · 만드는 중이 **한 모양 안에서 줄만 달라진다.** 상태마다
/// 다른 카드를 그리면 잔액이 줄 때 카드 높이와 모양이 뛰어 다른 화면처럼 보인다.
///
/// 낭독기는 한 덩어리로 읽는다 — 숫자·막대·안내가 따로 잡히면 "72" 만 읽고 무엇의
/// 72 인지 놓친다.
class AiCreditSummaryView extends StatelessWidget {
  const AiCreditSummaryView({super.key, required this.summary});

  final CreditSummary summary;

  /// 적음(<11) 안내. 직전 안내(질문·보상 화면)와 같은 말을 한다.
  static const lowLine = '그림이 여러 장 생성돼도 이번 일과는 끝까지 만들어지고 크레딧은 0이 될 수 있어요';

  static const _dividerGap = 14.0;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final space = context.space;
    final s = summary;

    final amount = '${s.available} / ${s.weeklyGrant} 크레딧 남음';
    final bonus = s.bonus > 0 ? '+ 추가 ${s.bonus}' : null;
    final lines = <(String, Color)>[
      if (s.isGeneratingRoutine) ('일과를 만들고 있어요', colors.textPrimary),
      if (s.isExhausted) ...[
        ('이번 주 크레딧을 모두 사용했어요', colors.textPrimary),
        ('만든 일과 보기와 직접 고치기는 계속 할 수 있어요', colors.textSecondary),
      ] else ...[
        (
          '일과 글 만들기 ${s.routineTextCost}크레딧 · '
              '완성된 AI 그림 1장당 ${s.cardImageCost}크레딧',
          colors.textPrimary,
        ),
        if (s.isLow) (lowLine, colors.creditAccentText),
      ],
    ];
    final reset = '${s.resetLabel}에 다시 채워져요';

    return Semantics(
      key: AiCreditCard.contentKey,
      container: true,
      excludeSemantics: true,
      label: [
        '이번 주 AI 생성',
        amount,
        ?bonus,
        for (final (text, _) in lines) text,
        reset,
      ].join(', '),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '이번 주 AI 생성',
            style: context.typo.creditTitle.copyWith(color: colors.textPrimary),
          ),
          SizedBox(height: space.sm),
          // 숫자와 단위를 한 문단으로 둔다 — 글꼴이 커지면 단위가 다음 줄로 흐른다.
          Text.rich(
            TextSpan(
              children: [
                TextSpan(
                  text: '${s.available}',
                  style: context.typo.creditNumber.copyWith(
                    color: colors.textPrimary,
                  ),
                ),
                TextSpan(
                  text: ' / ${s.weeklyGrant} 크레딧 남음',
                  style: context.typo.creditBody.copyWith(
                    color: colors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          if (bonus != null)
            Text(
              bonus,
              style: context.typo.creditCaption.copyWith(
                color: colors.creditAccentText,
              ),
            ),
          SizedBox(height: space.sm),
          AiCreditBar(
            key: AiCreditCard.barKey,
            ratio: s.remainingRatio,
            color: colors.creditBarFill,
          ),
          SizedBox(height: space.md),
          for (final (i, (text, color)) in lines.indexed) ...[
            if (i > 0) SizedBox(height: space.xs / 2),
            Text(text, style: context.typo.creditBody.copyWith(color: color)),
          ],
          SizedBox(height: _dividerGap.h),
          Divider(height: 1, thickness: 1, color: colors.creditDivider),
          SizedBox(height: _dividerGap.h),
          Text(
            reset,
            style: context.typo.creditBody.copyWith(color: colors.textSecondary),
          ),
        ],
      ),
    );
  }
}
