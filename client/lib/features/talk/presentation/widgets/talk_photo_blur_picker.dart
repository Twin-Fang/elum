import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../core/l10n/l10n_context.dart';
import '../../../../core/theme/app_motion.dart';
import '../../../../core/theme/theme_context_ext.dart';
import '../../../../core/widgets/app_pressable.dart';
import '../../../../shared/models/action_card.dart';
import '../../domain/talk_preview.dart';
import 'talk_page_heading.dart';
import 'talk_share_step_card.dart';

/// 사진 고르기 (시안 1877:10456): 보호자 사진 카드마다 웜그레이 판 > 카드 > `흐리게 | 그대로` (기본 그대로)
/// 2열 격자, 고르면 카드 그림이 바로 흐려진다
class TalkPhotoBlurPicker extends StatelessWidget {
  const TalkPhotoBlurPicker({
    super.key,
    required this.routineId,
    required this.photoSteps,
    required this.cardByStepId,
    required this.blurChoiceByStepId,
    required this.onChoose,
    this.isEnabled = true,
  });

  final String routineId;

  /// 보호자 사진 카드만
  final List<TalkPreviewStep> photoSteps;
  final Map<String, ActionCard> cardByStepId;

  /// null 이면 아직 고르지 않음
  final Map<String, bool?> blurChoiceByStepId;
  final void Function(String stepId, {required bool shouldBlur}) onChoose;
  final bool isEnabled;

  /// 안내 > 격자 · 판 줄 사이 (시안 안내 끝 206.6 > 판 232 를 간격 단계 24 로, 판 486 > 510)
  static const _headingToGrid = 24.0;
  static const _panelRowSpacing = 24.0;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TalkPageHeading(
          title: l10n.talkSharePhotoTitle,
          description: l10n.talkSharePhotoGuide,
        ),
        SizedBox(height: _headingToGrid.h),
        TalkShareCardGrid(
          itemCount: photoSteps.length,
          isCenteredWhenSingle: true,
          rowSpacing: _panelRowSpacing,
          itemBuilder: (context, index, cellWidth) {
            final step = photoSteps[index];
            return _PhotoChoicePanel(
              routineId: routineId,
              step: step,
              card: cardByStepId[step.stepId],
              panelWidth: cellWidth,
              shouldBlur: blurChoiceByStepId[step.stepId],
              onChoose: isEnabled
                  ? (shouldBlur) => onChoose(step.stepId, shouldBlur: shouldBlur)
                  : null,
            );
          },
        ),
      ],
    );
  }
}

/// 사진 카드 한 칸: 판(176, 모서리 16, 안쪽 8) > 카드 160 > 8 > `흐리게 | 그대로` (사이 4)
class _PhotoChoicePanel extends StatelessWidget {
  const _PhotoChoicePanel({
    required this.routineId,
    required this.step,
    required this.card,
    required this.panelWidth,
    required this.shouldBlur,
    required this.onChoose,
  });

  final String routineId;
  final TalkPreviewStep step;
  final ActionCard? card;
  final double panelWidth;

  /// true 흐리게 · false 그대로 · null 아직 안 고름
  final bool? shouldBlur;

  /// null 이면 잠긴다 (올리는 중)
  final ValueChanged<bool>? onChoose;

  static const _panelRadius = 16.0;
  static const _panelInset = 8.0;
  static const _cardToButtons = 8.0;
  static const _buttonGap = 4.0;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final onChoose = this.onChoose;
    final panelInsetWidth = _panelInset.w;

    return Container(
      padding: EdgeInsets.all(panelInsetWidth),
      decoration: BoxDecoration(
        color: context.colors.talkBlurChoicePanelFill,
        borderRadius: BorderRadius.circular(_panelRadius.r),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TalkShareStepCard(
            routineId: routineId,
            step: step,
            card: card,
            // 색 판은 카드 순서를 따른다 (stepOrder 는 1부터)
            index: step.stepOrder - 1,
            width: panelWidth - panelInsetWidth * 2,
            isBlurred: shouldBlur == true,
          ),
          SizedBox(height: _cardToButtons.h),
          Row(
            children: [
              Expanded(
                child: _BlurChoiceButton(
                  label: l10n.talkSharePhotoBlur,
                  isSelected: shouldBlur == true,
                  onTap: onChoose == null ? null : () => onChoose(true),
                ),
              ),
              SizedBox(width: _buttonGap.w),
              Expanded(
                child: _BlurChoiceButton(
                  label: l10n.talkSharePhotoKeep,
                  isSelected: shouldBlur == false,
                  onTap: onChoose == null ? null : () => onChoose(false),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// `흐리게` · `그대로` 버튼: 고름 진남색 · 안 고름 웜그레이, 글자는 둘 다 흰색 (시안 78×34, 모서리 8)
class _BlurChoiceButton extends StatelessWidget {
  const _BlurChoiceButton({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  final String label;
  final bool isSelected;
  final VoidCallback? onTap;

  static const _radius = 8.0;
  static const _paddingV = 10.0;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Semantics(
      selected: isSelected,
      button: true,
      enabled: onTap != null,
      child: AppPressable(
        onTap: onTap,
        child: AnimatedContainer(
          duration: AppMotion.fast,
          curve: AppMotion.standard,
          padding: EdgeInsets.symmetric(vertical: _paddingV.h),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: isSelected
                ? colors.talkBlurChoiceSelectedFill
                : colors.talkBlurChoiceFill,
            borderRadius: BorderRadius.circular(_radius.r),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            maxLines: 1,
            style: context.typo.talkBlurChoiceLabel.copyWith(
              color: colors.talkBlurChoiceLabel,
            ),
          ),
        ),
      ),
    );
  }
}
