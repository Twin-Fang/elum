import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../core/l10n/l10n_context.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/theme/theme_context_ext.dart';
import '../../../../core/widgets/elum_dialog.dart';
import '../../../../core/widgets/elum_sheet_text_field.dart';

/// 회원탈퇴 둘째 단계: `회원탈퇴` 입력 확인 팝업. 문구가 맞아야 탈퇴하기가 켜지고, 누르면 true
///
/// ⚠️ 시안 없는 임시 배치: 팝업 틀(`ElumDialogSurface`·버튼 줄) + 시트 입력칸(`ElumSheetTextField`) 조합
/// 바깥 누름·뒤로가기 = 취소 (false). 닫히면 입력은 팝업과 함께 버려짐
Future<bool> confirmWithdrawByTyping(BuildContext context) async {
  final isConfirmed = await showElumDialogContent<bool>(
    context: context,
    barrierDismissible: true,
    builder: (_) => const WithdrawTypeConfirmDialog(),
  );
  return isConfirmed ?? false;
}

class WithdrawTypeConfirmDialog extends StatefulWidget {
  const WithdrawTypeConfirmDialog({super.key});

  @override
  State<WithdrawTypeConfirmDialog> createState() =>
      _WithdrawTypeConfirmDialogState();
}

class _WithdrawTypeConfirmDialogState extends State<WithdrawTypeConfirmDialog> {
  final _phraseController = TextEditingController();

  /// 제목 묶음 > 버튼 (`ElumDialogCard` 와 같은 32)
  static const _bodyToActions = 32.0;

  @override
  void dispose() {
    _phraseController.dispose();
    super.dispose();
  }

  /// 입력 <-> ARB 문구 (앞뒤 공백 무시, 붙여넣기 허용)
  bool _isPhraseMatched(String requiredPhrase) =>
      _phraseController.text.trim() == requiredPhrase;

  void _close({required bool isConfirmed}) {
    _phraseController.clear();
    Navigator.of(context).pop(isConfirmed);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colors = context.colors;
    final requiredPhrase = l10n.guardianSettingsWithdrawTypePhrase;
    final isPhraseMatched = _isPhraseMatched(requiredPhrase);

    // Dialog 가 키보드 높이(viewInsets)만큼 띄움 · 큰 글자에서 넘치면 안에서 스크롤
    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      insetPadding: EdgeInsets.zero,
      child: ElumDialogSurface(
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 제목 > 안내 (팝업 글자 토큰 그대로)
              Text(
                l10n.guardianSettingsWithdrawTypeTitle,
                textAlign: TextAlign.center,
                style: context.typo.dialogTitle.copyWith(
                  color: colors.dialogTitleText,
                ),
              ),
              SizedBox(height: context.space.sm),
              Text(
                l10n.guardianSettingsWithdrawTypeMessage(requiredPhrase),
                textAlign: TextAlign.center,
                style: context.typo.body.paragraph.copyWith(
                  color: colors.textSecondary,
                ),
              ),
              SizedBox(height: context.space.md),
              // 입력칸: 안내 글 = 입력할 문구 그대로
              ElumSheetTextField(
                controller: _phraseController,
                hintText: requiredPhrase,
                isAutofocused: true,
                shouldBlockLineBreaks: true,
                onChanged: (_) => setState(() {}),
                onSubmitted: (_) {
                  if (_isPhraseMatched(requiredPhrase)) {
                    _close(isConfirmed: true);
                  }
                },
              ),
              SizedBox(height: _bodyToActions.h),
              // 취소 · 탈퇴하기 (문구가 맞을 때만 켜짐)
              ElumDialogButtonRow(
                children: [
                  ElumDialogButton(
                    label: l10n.commonCancel,
                    tone: ElumDialogTone.neutral,
                    onTap: () => _close(isConfirmed: false),
                  ),
                  ElumDialogButton(
                    label: l10n.guardianSettingsWithdrawTypeAction,
                    tone: ElumDialogTone.danger,
                    onTap: isPhraseMatched
                        ? () => _close(isConfirmed: true)
                        : null,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
