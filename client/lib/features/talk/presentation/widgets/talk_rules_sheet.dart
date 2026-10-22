import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../core/l10n/l10n_context.dart';
import '../../../../core/theme/app_motion.dart';
import '../../../../core/theme/theme_context_ext.dart';
import '../../../../core/widgets/app_fade_slide_in.dart';
import '../../../../core/widgets/elum_bottom_sheet.dart';
import '../../../../core/widgets/elum_button.dart';
import '../../../../core/widgets/show_failure.dart';
import '../../application/talk_rules_provider.dart';
import '../../domain/talk_screen_codes.dart';
import 'talk_choice_row.dart';
import '../../../../core/widgets/elum_sheet_frame.dart';

/// 이야기 이용 규칙에 동의했는지 확인 > 안 했으면 규칙 시트로 동의받기
/// 올리기 시작과 첫 댓글이 이 함수를 거친다. 동의했거나 이번에 동의하면 true
/// 확인·저장에 실패하면 안내를 띄우고 false ([fallbackCode] 는 호출한 화면의 추적 코드)
Future<bool> ensureTalkRulesAgreed(
  BuildContext context,
  WidgetRef ref, {
  String fallbackCode = TalkScreenCodes.comment,
}) async {
  final agreement = ref.read(talkRulesAgreementProvider.notifier);
  final l10n = context.l10n;
  try {
    if (await agreement.hasAgreed()) return true;
  } catch (e) {
    if (!context.mounted) return false;
    await showFailure(
      context,
      e,
      title: l10n.talkRulesFailedTitle,
      fallback: l10n.talkFailedFallback,
      fallbackCode: fallbackCode,
    );
    return false;
  }
  if (!context.mounted) return false;
  final isAgreed = await showElumSheet<bool>(
    context: context,
    builder: (_) => TalkRulesSheet(fallbackCode: fallbackCode),
  );
  return isAgreed ?? false;
}

/// 이용 규칙: 웜그레이 판에 번호 붙인 규칙 3줄 > 동의 체크 줄 > "동의하고 계속하기" (체크해야 켜진다)
class TalkRulesSheet extends ConsumerStatefulWidget {
  const TalkRulesSheet({super.key, required this.fallbackCode});

  final String fallbackCode;

  @override
  ConsumerState<TalkRulesSheet> createState() => _TalkRulesSheetState();
}

class _TalkRulesSheetState extends ConsumerState<TalkRulesSheet> {
  bool _isChecked = false;
  bool _isSaving = false;

  Future<void> _agree() async {
    if (!_isChecked || _isSaving) return;
    setState(() => _isSaving = true);
    final l10n = context.l10n;
    try {
      await ref.read(talkRulesAgreementProvider.notifier).agree();
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSaving = false);
      await showFailure(
        context,
        e,
        title: l10n.talkRulesFailedTitle,
        fallback: l10n.talkFailedFallback,
        fallbackCode: widget.fallbackCode,
      );
    }
  }

  /// 규칙 판 > 동의 줄 · 동의 줄 > 버튼
  static const _rulesToAgree = 16.0;
  static const _agreeToButton = 24.0;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final rules = [
      l10n.talkRulesPrivacy,
      l10n.talkRulesRespect,
      l10n.talkRulesNoDiagnosis,
    ];

    return ElumSheetFrame(
      title: l10n.talkRulesTitle,
      description: l10n.talkRulesIntro,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _RulesPanel(rules: rules),
          SizedBox(height: _rulesToAgree.h),
          TalkChoiceRow(
            label: l10n.talkRulesAgreeCheck,
            indicator: TalkChoiceIndicator.check,
            isSelected: _isChecked,
            onTap: _isSaving
                ? null
                : () => setState(() => _isChecked = !_isChecked),
          ),
          SizedBox(height: _agreeToButton.h),
          ElumButton(
            label: l10n.talkRulesAgreeButton,
            labelStyle: context.typo.sheetActionLabel,
            loading: _isSaving,
            onPressed: _isChecked ? _agree : null,
          ),
        ],
      ),
    );
  }
}

/// 규칙 판: 웜그레이 r20 판 안에 번호 원 + 규칙 한 줄씩, 차례로 떠오른다
class _RulesPanel extends StatelessWidget {
  const _RulesPanel({required this.rules});

  final List<String> rules;

  /// 판 안쪽 · 규칙 사이
  static const _padding = 20.0;
  static const _ruleGap = 16.0;

  /// 규칙 사이 떠오르는 간격 (기본 stagger 의 3배: 한 줄씩 읽히게)
  static const _staggerSteps = 3;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(_padding.w),
      decoration: BoxDecoration(
        color: context.colors.talkPanelFill,
        borderRadius: BorderRadius.circular(context.space.cardRadius.r),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var index = 0; index < rules.length; index++) ...[
            if (index > 0) SizedBox(height: _ruleGap.h),
            AppFadeSlideIn(
              offset: 8,
              delay: Duration(
                milliseconds:
                    AppMotion.staggerDelayMs * _staggerSteps * (index + 2),
              ),
              child: _RuleLine(number: index + 1, text: rules[index]),
            ),
          ],
        ],
      ),
    );
  }
}

/// 규칙 한 줄: 민트 번호 원 + 문장 (두 줄이면 원은 첫 줄에 맞춘다)
class _RuleLine extends StatelessWidget {
  const _RuleLine({required this.number, required this.text});

  final int number;
  final String text;

  static const _badgeSize = 24.0;
  static const _badgeToText = 12.0;

  /// 문장 첫 줄(15 × 1.4 = 21)과 원(24) 가운데를 맞추는 위 여백
  static const _textTopNudge = 1.5;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typo = context.typo;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: _badgeSize.w,
          height: _badgeSize.w,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: colors.goalSelectedFill,
          ),
          child: Text(
            '$number',
            style: typo.talkFormLabel.copyWith(color: colors.textPrimary),
          ),
        ),
        SizedBox(width: _badgeToText.w),
        Expanded(
          child: Padding(
            padding: EdgeInsets.only(top: _textTopNudge.h),
            child: Text(
              text,
              style: typo.talkRuleText.copyWith(color: colors.textPrimary),
            ),
          ),
        ),
      ],
    );
  }
}
