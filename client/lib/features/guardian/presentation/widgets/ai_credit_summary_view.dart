import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../../core/l10n/current_l10n.dart';
import '../../../../core/l10n/l10n_context.dart';
import '../../../../core/assets/app_assets.dart';
import '../../../../core/theme/theme_context_ext.dart';
import '../../../../core/widgets/app_pressable.dart';
import '../../../../core/widgets/elum_dialog.dart';
import '../../../credit/domain/credit_summary.dart';
import 'ai_credit_card.dart';
import 'credit_history_link.dart';

/// 크레딧 카드 안의 내용 — 조회에 성공했을 때.
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

  /// 막대 > 알릴 줄 > 다시 채워지는 날 사이 (Figma `1579:8122` gap 16)
  static const _sectionGap = 16.0;

  /// 큰 숫자 옆 반짝임 (Figma `1579:8119` 20×24)와 숫자·단위 사이 (gap 4)
  static const _sparkleWidth = 20.0;
  static const _sparkleHeight = 24.0;
  static const _inlineGap = 4.0;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final space = context.space;
    final s = summary;

    // 단위 문구는 앞 공백 없이 쓴다 (`/ 100 크레딧 남음`)
    final unit = context.l10n.creditAmountRest(s.weeklyGrant).trim();
    final amount = context.l10n.creditAmountLeft(s.available, s.weeklyGrant);
    // 보너스는 따로 적지 않는다 — 큰 숫자(available)에 이미 들어 있어 `+ 추가 N` 은
    // 합계를 부풀려 읽히게 한다.
    final lines = <(String, Color)>[
      if (s.isGeneratingRoutine)
        (context.l10n.creditGenerating, colors.textPrimary),
      // 적을 때 "끝까지 만들어지지만 0 이 될 수 있다"는 경고는 두지 않는다 — 숫자와
      // 막대로 충분하고, 경고 문구는 이상하고 불편하다.
      if (s.isExhausted) ...[
        (context.l10n.creditExhausted, colors.textPrimary),
        (context.l10n.creditExhaustedStillOk, colors.textSecondary),
      ],
    ];
    final reset = context.l10n.aiCreditResetLine(s.resetLabel);

    // 낭독기는 한 덩어리로 읽는다. 안내 버튼은 덩어리 밖에 둬야 따로 잡힌다.
    final body = Semantics(
      key: AiCreditCard.contentKey,
      container: true,
      excludeSemantics: true,
      label: [
        context.l10n.creditCardTitle,
        amount,
        for (final (text, _) in lines) text,
        reset,
      ].join(', '),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 제목 줄의 안내 버튼 자리 (누름 영역이 제목 줄보다 높아 위로 겹쳐 둔다)
          SizedBox(height: CreditInfoButton.titleRowHeight(context)),
          SizedBox(height: space.xs),
          // 반짝임 + 큰 숫자, 오른쪽에 단위 (글꼴이 커지면 단위가 다음 줄로 흐른다)
          Wrap(
            crossAxisAlignment: WrapCrossAlignment.end,
            spacing: _inlineGap.w,
            runSpacing: _inlineGap.h,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  SvgPicture.asset(
                    AppAssets.iconSparkles,
                    width: _sparkleWidth.w,
                    height: _sparkleHeight.h,
                    colorFilter: ColorFilter.mode(
                      colors.creditNumberText,
                      BlendMode.srcIn,
                    ),
                  ),
                  SizedBox(width: _inlineGap.w),
                  Text(
                    '${s.available}',
                    style: context.typo.creditNumber.copyWith(
                      color: colors.creditNumberText,
                    ),
                  ),
                ],
              ),
              Text(
                unit,
                style: context.typo.creditUnit.copyWith(
                  color: colors.creditMutedText,
                ),
              ),
            ],
          ),
          SizedBox(height: space.xs),
          AiCreditBar(
            key: AiCreditCard.barKey,
            ratio: s.remainingRatio,
            color: colors.creditBarFill,
          ),
          // 알릴 줄이 없는 정상 상태면 막대 아래에 바로 다시 채워지는 날이 온다
          if (lines.isNotEmpty) ...[
            SizedBox(height: space.md),
            for (final (i, (text, color)) in lines.indexed) ...[
              if (i > 0) SizedBox(height: space.xs / 2),
              Text(text, style: context.typo.creditBody.copyWith(color: color)),
            ],
          ],
          SizedBox(height: _sectionGap.h),
          Text(
            reset,
            style: context.typo.creditReset.copyWith(
              color: colors.creditMutedText,
            ),
          ),
        ],
      ),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Stack(
          children: [
            body,
            Positioned(top: 0, left: 0, right: 0, child: CreditInfoButton(summary: s)),
          ],
        ),
        // 다시 채워지는 날 > 사용 내역 보기: 시안 간격 16 에서 누름 영역이 12 를 가져간다
        SizedBox(height: (_sectionGap - CreditHistoryLink.tapExtraVertical).h),
        const CreditHistoryLink(),
      ],
    );
  }
}

/// 제목 줄(`이번 주 AI 생성 ⓘ`): 제목 옆 물음표를 누르면 크레딧이 어떻게 줄어드는지 팝업으로 알린다.
///
/// 제목 줄 전체가 누름 영역이다 — 물음표 16 만으로는 작다. 그림은 보상 도움말의 물음표 원을 그대로 쓴다.
class CreditInfoButton extends StatelessWidget {
  const CreditInfoButton({super.key, required this.summary});

  final CreditSummary summary;

  /// 누름 영역 높이 — 일반 터치 최소치.
  static const box = 44.0;

  /// 제목과 물음표 사이 (Figma `1579:8114` gap 6) 와 물음표 크기 (16)
  static const _gap = 6.0;
  static const _icon = 16.0;

  /// 안내 팝업을 띄울 때 읽는다 — 값을 들고 있지 말고 부를 때마다 앱 언어로 푼다.
  static String get title => appL10n.creditCostTitle;

  /// 서버 단가로 적는다 — 운영에서 단가를 바꾸면 문구도 따라간다.
  static String message(CreditSummary s) => [
    appL10n.creditCostLine(s.routineTextCost, s.cardImageCost),
    appL10n.creditCostKeepGoing,
    appL10n.creditWeeklyRefill,
  ].join('\n');

  /// 제목 한 줄 높이 (글꼴 배율 반영). 본문이 이 아래에서 시작한다.
  static double titleRowHeight(BuildContext context) {
    final style = context.typo.creditTitle;
    return MediaQuery.textScalerOf(context).scale(style.fontSize ?? _icon) *
        (style.height ?? 1);
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final line = titleRowHeight(context);
    // 누름 영역이 제목 줄보다 높으므로 위로 겹쳐 올린다 (카드 위 안쪽 여백 안에서)
    final overhang = math.max(0.0, (box - line) / 2);

    return Transform.translate(
      offset: Offset(0, -overhang),
      child: AppPressable(
        key: AiCreditCard.infoKey,
        scaleDown: AppPressable.scaleIcon,
        semanticLabel: context.l10n.creditInfoLabel,
        onTap: () => showElumDialog<void>(
          context: context,
          title: title,
          message: message(summary),
          barrierDismissible: true,
          // 팝업 폭에서 낱말 가운데서 꺾이지 않게 한다 (보상 도움말과 같은 선택)
          keepWordsInMessage: true,
        ),
        child: SizedBox(
          height: math.max(box, line),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Flexible(
                  child: Text(
                    context.l10n.creditCardTitle,
                    style: context.typo.creditTitle.copyWith(
                      color: colors.textPrimary,
                    ),
                  ),
                ),
                SizedBox(width: _gap.w),
                SvgPicture.asset(
                  AppAssets.iconQuestionCircle,
                  width: _icon.w,
                  height: _icon.w,
                  colorFilter: ColorFilter.mode(
                    colors.creditMutedText,
                    BlendMode.srcIn,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
