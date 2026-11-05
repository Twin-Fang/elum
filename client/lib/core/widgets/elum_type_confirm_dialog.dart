import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../l10n/l10n_context.dart';
import '../theme/app_typography.dart';
import '../theme/theme_context_ext.dart';
import 'elum_dialog.dart';
import 'elum_sheet_text_field.dart';

/// 되돌릴 수 없는 동작의 입력 확인 팝업: 문구가 맞아야 실행 버튼이 켜지고, 누르면 true
///
/// ⚠️ 시안 없는 임시 배치: 팝업 틀(`ElumDialogSurface`·버튼 줄) + 시트 입력칸(`ElumSheetTextField`) 조합
/// 바깥 누름·뒤로가기 = 취소 (false). 닫히면 입력은 팝업과 함께 버려짐
Future<bool> confirmByTyping(
  BuildContext context, {
  required String requiredPhrase,
  required String title,
  required String message,
  required String actionLabel,
}) async {
  final isConfirmed = await showElumDialogContent<bool>(
    context: context,
    barrierDismissible: true,
    builder: (_) => ElumTypeConfirmDialog(
      requiredPhrase: requiredPhrase,
      title: title,
      message: message,
      actionLabel: actionLabel,
    ),
  );
  return isConfirmed ?? false;
}

class ElumTypeConfirmDialog extends StatefulWidget {
  const ElumTypeConfirmDialog({
    super.key,
    required this.requiredPhrase,
    required this.title,
    required this.message,
    required this.actionLabel,
  });

  /// 입력해야 하는 문구 (ARB 원본). 비교 기준이자 입력칸 안내 글
  final String requiredPhrase;
  final String title;

  /// 제목 아래 안내. 입력할 문구를 담아 호출부가 만듦
  final String message;

  /// 위험색 실행 버튼 이름
  final String actionLabel;

  @override
  State<ElumTypeConfirmDialog> createState() => _ElumTypeConfirmDialogState();
}

class _ElumTypeConfirmDialogState extends State<ElumTypeConfirmDialog> {
  final _phraseController = TextEditingController();

  /// 제목 묶음 > 버튼 (`ElumDialogCard` 와 같은 32)
  static const _bodyToActions = 32.0;

  @override
  void dispose() {
    _phraseController.dispose();
    super.dispose();
  }

  /// 입력 <-> 필요 문구 (앞뒤 공백 무시, 붙여넣기 허용)
  bool get _isPhraseMatched =>
      _phraseController.text.trim() == widget.requiredPhrase;

  void _close({required bool isConfirmed}) {
    _phraseController.clear();
    Navigator.of(context).pop(isConfirmed);
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final isPhraseMatched = _isPhraseMatched;

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
                widget.title,
                textAlign: TextAlign.center,
                style: context.typo.dialogTitle.copyWith(
                  color: colors.dialogTitleText,
                ),
              ),
              SizedBox(height: context.space.sm),
              Text(
                widget.message,
                textAlign: TextAlign.center,
                style: context.typo.body.paragraph.copyWith(
                  color: colors.textSecondary,
                ),
              ),
              SizedBox(height: context.space.md),
              // 입력칸: 안내 글 = 입력할 문구 그대로
              ElumSheetTextField(
                controller: _phraseController,
                hintText: widget.requiredPhrase,
                isAutofocused: true,
                shouldBlockLineBreaks: true,
                onChanged: (_) => setState(() {}),
                onSubmitted: (_) {
                  if (_isPhraseMatched) {
                    _close(isConfirmed: true);
                  }
                },
              ),
              SizedBox(height: _bodyToActions.h),
              // 취소 · 실행 (문구가 맞을 때만 켜짐)
              ElumDialogButtonRow(
                children: [
                  ElumDialogButton(
                    label: context.l10n.commonCancel,
                    tone: ElumDialogTone.neutral,
                    onTap: () => _close(isConfirmed: false),
                  ),
                  ElumDialogButton(
                    label: widget.actionLabel,
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
