import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../../core/assets/app_assets.dart';
import '../../../../core/theme/theme_context_ext.dart';
import '../../../../core/widgets/app_pressable.dart';
import '../../../../core/widgets/elum_dialog.dart';
import '../../../credit/domain/credit_summary.dart';
import 'ai_credit_card.dart';

/// 크레딧 카드 안의 내용 — 조회에 성공했을 때 (#407).
///
/// 정상 · 보너스 · 적음 · 0 · 만드는 중이 **한 모양 안에서 줄만 달라진다.** 상태마다
/// 다른 카드를 그리면 잔액이 줄 때 카드 높이와 모양이 뛰어 다른 화면처럼 보인다.
///
/// 낭독기는 한 덩어리로 읽는다 — 숫자·막대·안내가 따로 잡히면 "72" 만 읽고 무엇의
/// 72 인지 놓친다. 안내 버튼만 따로 잡힌다 — 눌러야 하는 것이라서.
///
/// 단가는 카드에 적지 않고 제목 옆 안내 버튼 팝업으로 옮겼다. 카드 폭에서
/// `1크레 / 딧` 처럼 낱말 가운데서 꺾였고, 매번 볼 정보도 아니다.
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
      ] else if (s.isLow)
        (lowLine, colors.creditAccentText),
    ];
    final reset = '${s.resetLabel}에 다시 채워져요';

    final body = Semantics(
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
          // 오른쪽은 안내 버튼 자리 — 큰 글꼴에서도 제목이 버튼 밑으로 흐르지 않는다
          Padding(
            padding: EdgeInsets.only(right: CreditInfoButton.box),
            child: Text(
              '이번 주 AI 생성',
              style: context.typo.creditTitle.copyWith(
                color: colors.textPrimary,
              ),
            ),
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
          // 알릴 줄이 없는 정상 상태면 막대 → 구분선을 바로 잇는다 (빈 간격이 겹치지 않게)
          if (lines.isNotEmpty) ...[
            SizedBox(height: space.md),
            for (final (i, (text, color)) in lines.indexed) ...[
              if (i > 0) SizedBox(height: space.xs / 2),
              Text(text, style: context.typo.creditBody.copyWith(color: color)),
            ],
          ],
          SizedBox(height: _dividerGap.h),
          Divider(height: 1, thickness: 1, color: colors.creditDivider),
          SizedBox(height: _dividerGap.h),
          Text(
            reset,
            style: context.typo.creditBody.copyWith(
              color: colors.textSecondary,
            ),
          ),
        ],
      ),
    );

    // 버튼을 내용 덩어리(excludeSemantics) 밖에 둬야 낭독기가 따로 잡는다.
    // 누름 영역(44)이 제목 줄보다 높아 줄 안에 두면 아래가 밀린다 — 겹쳐 올린다.
    return Stack(
      children: [
        body,
        Positioned(top: 0, right: 0, child: CreditInfoButton(summary: s)),
      ],
    );
  }
}

/// 제목 오른쪽 안내 버튼 — 크레딧이 어떻게 줄어드는지 팝업으로 알린다.
///
/// 그림은 보상 도움말(`보상이 왜 필요한가요?`)의 물음표 원을 그대로 쓴다.
class CreditInfoButton extends StatelessWidget {
  const CreditInfoButton({super.key, required this.summary});

  final CreditSummary summary;

  /// 누름 영역 — 일반 터치 최소치.
  static const box = 44.0;
  static const _icon = 18.0;

  static const title = 'AI 크레딧은 이렇게 줄어요';

  /// 서버 단가로 적는다 — 운영에서 단가를 바꾸면 문구도 따라간다.
  static String message(CreditSummary s) => [
    '일과 글을 만들 때 ${s.routineTextCost}개, '
        '그림이 완성된 카드 1장마다 ${s.cardImageCost}개씩 써요.',
    '크레딧이 남아 있을 때 시작한 일과는 그림이 많아도 끝까지 만들어져요.',
    '매주 월요일 0시에 다시 채워져요.',
  ].join('\n');

  @override
  Widget build(BuildContext context) {
    // 그림을 제목 첫 줄 가운데에 맞춘다. 글꼴 크기를 키우면 줄이 높아지므로
    // 고정 값 대신 지금 배율로 줄 높이를 잰다.
    final style = context.typo.creditTitle;
    final line =
        MediaQuery.textScalerOf(context).scale(style.fontSize ?? _icon) *
        (style.height ?? 1);
    final icon = _icon.w;

    return AppPressable(
      key: AiCreditCard.infoKey,
      scaleDown: AppPressable.scaleIcon,
      semanticLabel: 'AI 크레딧 안내',
      onTap: () => showElumDialog<void>(
        context: context,
        title: title,
        message: message(summary),
        barrierDismissible: true,
        // 팝업 폭에서 낱말 가운데서 꺾이지 않게 (#393 S4 보상 도움말과 같은 선택)
        keepWordsInMessage: true,
      ),
      child: SizedBox(
        width: box,
        height: math.max(box, line),
        child: Align(
          alignment: Alignment.topRight,
          child: Padding(
            padding: EdgeInsets.only(top: math.max(0, (line - icon) / 2)),
            child: SvgPicture.asset(
              AppAssets.iconQuestionCircle,
              width: icon,
              height: icon,
            ),
          ),
        ),
      ),
    );
  }
}
