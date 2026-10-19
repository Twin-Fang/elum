import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../../core/assets/app_assets.dart';
import '../../../../core/l10n/content_locale.dart';
import '../../../../core/l10n/l10n_context.dart';
import '../../../../core/theme/app_motion.dart';
import '../../../../core/theme/theme_context_ext.dart';
import '../../../../core/widgets/app_pressable.dart';
import '../../../../shared/models/action_card.dart';
import '../../../guardian/domain/card_palette.dart';

/// 태블릿 카드 상세 위쪽 순서 줄: 단계 칸들 + 끝에 보상 목표 칸 (#789)
///
/// 칸 상태 3개: 한 것(체크), 지금 카드(크게·테두리), 아직(번호). 칸을 누르면 그 카드로 간다.
/// 보상이 있으면 맨 끝에 "다하면 / 🍪 젤리 먹기" 목표 칸 — 끝까지 가면 무엇을 받는지 늘 보인다.
class ChildStepStrip extends StatelessWidget {
  const ChildStepStrip({
    super.key,
    required this.cards,
    required this.currentIndex,
    required this.isChecked,
    required this.onStepTap,
    this.rewardEmoji = '',
    this.rewardText = '',
    this.language = 'ko',
  });

  final List<ActionCard> cards;
  final int currentIndex;
  final bool Function(ActionCard card) isChecked;
  final ValueChanged<int> onStepTap;

  /// 보상. 글이 비면 목표 칸을 그리지 않는다
  final String rewardEmoji;
  final String rewardText;

  /// 보상 글의 언어 (일과 언어)
  final String language;

  /// 단계 칸 한 변·지금 칸 한 변·칸 사이 (393 기준)
  static const stepSize = 44.0;
  static const currentStepSize = 56.0;
  static const _stepGap = 10.0;

  /// 목표 칸 최대 폭 (393 기준)
  static const _goalMaxWidth = 220.0;

  static ValueKey<String> stepKey(int index) => ValueKey('child.step.$index');
  static const goalKey = ValueKey('child.step.goal');

  bool get _hasReward => rewardText.isNotEmpty;

  @override
  Widget build(BuildContext context) {
    if (cards.isEmpty) return const SizedBox.shrink();

    return SizedBox(
      height: currentStepSize.w,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // 단계가 많으면 칸 줄만 옆으로 밀린다. 목표 칸은 늘 보이게 밖에 둔다
          Flexible(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  for (final (index, card) in cards.indexed) ...[
                    if (index > 0) _StepConnector(isDone: isChecked(card)),
                    _StepChip(
                      key: stepKey(index),
                      order: index + 1,
                      total: cards.length,
                      palette: CardPalette.at(index),
                      isCurrent: index == currentIndex,
                      isDone: isChecked(card),
                      onTap: () => onStepTap(index),
                    ),
                  ],
                ],
              ),
            ),
          ),
          if (_hasReward) ...[
            const _StepConnector(isDone: false),
            ConstrainedBox(
              constraints: BoxConstraints(maxWidth: _goalMaxWidth.w),
              child: _GoalChip(
                key: goalKey,
                emoji: rewardEmoji,
                text: rewardText,
                language: language,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// 칸 사이 짧은 선. 앞 칸까지 했으면 진한 색
class _StepConnector extends StatelessWidget {
  const _StepConnector({required this.isDone});

  final bool isDone;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Container(
      width: ChildStepStrip._stepGap.w * 1.6,
      height: 3.w,
      margin: EdgeInsets.symmetric(horizontal: 2.w),
      decoration: BoxDecoration(
        color: isDone ? colors.checkDone : colors.routineRingTrack,
        borderRadius: BorderRadius.circular(2.w),
      ),
    );
  }
}

/// 단계 칸 하나 (한 것: 민트 체크 / 지금: 크게 / 아직: 번호)
class _StepChip extends StatelessWidget {
  const _StepChip({
    super.key,
    required this.order,
    required this.total,
    required this.palette,
    required this.isCurrent,
    required this.isDone,
    required this.onTap,
  });

  final int order;
  final int total;
  final CardPalette palette;
  final bool isCurrent;
  final bool isDone;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final size =
        (isCurrent ? ChildStepStrip.currentStepSize : ChildStepStrip.stepSize)
            .w;

    return AppPressable(
      onTap: onTap,
      scaleDown: AppPressable.scaleIcon,
      semanticLabel: context.l10n.childCardPagerLabel(total, order),
      child: AnimatedContainer(
        // 아동 화면 전환은 300ms 이상
        duration: AppMotion.normal,
        curve: AppMotion.standard,
        width: size,
        height: size,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: isDone ? colors.checkDone : palette.fill,
          borderRadius: BorderRadius.circular(size * 0.3),
          border: Border.all(
            color: isCurrent ? colors.textPrimary : palette.border,
            width: (isCurrent ? 3 : 2).w,
          ),
        ),
        child: isDone
            ? SvgPicture.asset(
                AppAssets.childCheckMark,
                width: size * 0.5,
                height: size * 0.37,
                colorFilter: ColorFilter.mode(colors.surface, BlendMode.srcIn),
                excludeFromSemantics: true,
              )
            : Text(
                '$order',
                // 배지 숫자 토큰을 칸 크기에 맞춰 줄인다 (지금 칸이 더 크다)
                textScaler: TextScaler.linear(
                  MediaQuery.textScalerOf(context).scale(1) *
                      (isCurrent ? 0.8 : 0.6),
                ),
                style: context.typo.cardHeadline.copyWith(
                  color: colors.textPrimary,
                ),
              ),
      ),
    );
  }
}

/// 끝 칸: 보상 목표 ("다하면" 작게 + 보상 크게)
class _GoalChip extends StatelessWidget {
  const _GoalChip({
    super.key,
    required this.emoji,
    required this.text,
    required this.language,
  });

  final String emoji;
  final String text;
  final String language;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typo = context.typo;
    // 직접 적은 보상에는 그림이 없다
    final display = emoji.isEmpty ? text : '$emoji $text';

    return Container(
      height: ChildStepStrip.currentStepSize.w,
      padding: EdgeInsets.symmetric(horizontal: 14.w),
      decoration: BoxDecoration(
        color: colors.stepStripGoalFill,
        borderRadius: BorderRadius.circular(16.w),
        border: Border.all(color: colors.stepStripGoalBorder, width: 2.w),
      ),
      // 글자를 크게 키워도 칸 높이 안에 들도록 통째로 줄인다
      child: FittedBox(
        fit: BoxFit.scaleDown,
        alignment: Alignment.centerLeft,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              // 화면 문구 "다하면 " 의 끝 공백 제거
              context.l10n.rewardBannerPrefix.trim(),
              style: typo.caption.copyWith(color: colors.routineTileLabel),
            ),
            Text(
              display,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: typo.rewardChipLabel.copyWith(
                locale: contentLocaleOf(language),
                color: colors.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
