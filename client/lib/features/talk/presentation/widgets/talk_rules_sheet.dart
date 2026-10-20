import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../core/l10n/l10n_context.dart';
import '../../../../core/theme/theme_context_ext.dart';
import '../../../../core/widgets/elum_bottom_sheet.dart';
import '../../../../core/widgets/elum_button.dart';
import '../../../../core/widgets/elum_check_row.dart';
import '../../../../core/widgets/show_failure.dart';
import '../../application/talk_rules_provider.dart';
import '../../domain/talk_screen_codes.dart';
import 'talk_sheet_frame.dart';

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

/// 이용 규칙 3줄 + 동의 체크 > "동의하고 계속하기" (체크해야 켜진다)
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

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colors = context.colors;
    final space = context.space;

    return TalkSheetFrame(
      title: l10n.talkRulesTitle,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            l10n.talkRulesIntro,
            style: context.typo.body.copyWith(color: colors.textSecondary),
          ),
          SizedBox(height: space.sm.h),
          _RuleLine(text: l10n.talkRulesPrivacy),
          _RuleLine(text: l10n.talkRulesRespect),
          _RuleLine(text: l10n.talkRulesNoDiagnosis),
          SizedBox(height: space.xs.h),
          ElumCheckRow(
            label: l10n.talkRulesAgreeCheck,
            checked: _isChecked,
            onChanged: _isSaving
                ? null
                : (isChecked) => setState(() => _isChecked = isChecked),
          ),
          SizedBox(height: space.sm.h),
          ElumButton(
            label: l10n.talkRulesAgreeButton,
            loading: _isSaving,
            onPressed: _isChecked ? _agree : null,
          ),
        ],
      ),
    );
  }
}

/// 규칙 한 줄: 체크 아이콘 + 문장
class _RuleLine extends StatelessWidget {
  const _RuleLine({required this.text});

  final String text;

  static const _iconSize = 20.0;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final space = context.space;
    return Padding(
      padding: EdgeInsets.symmetric(vertical: space.xs.h / 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.check_circle_rounded,
            size: _iconSize.w,
            color: colors.textPrimary,
          ),
          SizedBox(width: space.xs.w),
          Expanded(
            child: Text(
              text,
              style: context.typo.tileLabel.copyWith(color: colors.textPrimary),
            ),
          ),
        ],
      ),
    );
  }
}
