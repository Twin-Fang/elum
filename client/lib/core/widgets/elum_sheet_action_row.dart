import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../l10n/l10n_context.dart';
import '../theme/theme_context_ext.dart';
import 'elum_button.dart';

/// 시트 버튼 둘 (시안 1869:8838 · 1860:8714): `취소` 100 웜회색 + 사이 4 + 확인 남색 나머지
/// 버튼 하나면 `ElumButton` 을 그대로 쓴다
class ElumSheetActionRow extends StatelessWidget {
  const ElumSheetActionRow({
    super.key,
    required this.confirmLabel,
    required this.onConfirm,
    this.cancelLabel,
    this.onCancel,
    this.isLoading = false,
  });

  final String confirmLabel;

  /// null 이면 확인 버튼이 꺼진다
  final VoidCallback? onConfirm;

  /// 기본 `취소`
  final String? cancelLabel;

  /// 기본은 시트를 닫는다
  final VoidCallback? onCancel;

  /// 확인 버튼 자리에 로딩을 그리고 둘 다 막는다
  final bool isLoading;

  static const _cancelWidth = 100.0;
  static const _buttonGap = 4.0;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final labelStyle = context.typo.sheetActionLabel;
    return Row(
      children: [
        SizedBox(
          width: _cancelWidth.w,
          child: ElumButton(
            label: cancelLabel ?? context.l10n.commonCancel,
            labelStyle: labelStyle,
            backgroundColor: colors.dialogNeutral,
            labelColor: colors.dialogNeutralText,
            onPressed: isLoading
                ? null
                : (onCancel ?? () => Navigator.of(context).pop()),
          ),
        ),
        SizedBox(width: _buttonGap.w),
        Expanded(
          child: ElumButton(
            label: confirmLabel,
            labelStyle: labelStyle,
            loading: isLoading,
            onPressed: onConfirm,
          ),
        ),
      ],
    );
  }
}
