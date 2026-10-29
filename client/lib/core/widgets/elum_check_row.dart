import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../theme/theme_context_ext.dart';
import 'elum_check_circle.dart';

/// 체크 한 줄 (민트 원형 체크 [ElumCheckCircle] + 글). 줄 전체가 눌린다 (의견 보내기).
class ElumCheckRow extends StatelessWidget {
  const ElumCheckRow({
    super.key,
    required this.label,
    required this.checked,
    required this.onChanged,
    this.labelStyle,
  });

  final String label;
  final bool checked;

  /// null 이면 input 글꼴(기본). 화면 글꼴에 맞출 때만 넘긴다.
  final TextStyle? labelStyle;

  /// null 이면 잠긴다(전송 중).
  final ValueChanged<bool>? onChanged;

  /// 체크 > 글 (약관 줄 결 12)
  static const _checkToLabel = 12.0;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final onTap = onChanged;

    return Semantics(
      container: true,
      checked: checked,
      enabled: onTap != null,
      label: label,
      excludeSemantics: true,
      onTap: onTap == null ? null : () => onTap(!checked),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap == null ? null : () => onTap(!checked),
        child: ConstrainedBox(
          // 누르기 쉽게 줄 높이를 48 이상으로 둔다
          constraints: BoxConstraints(minHeight: 48.h),
          child: Row(
            children: [
              ElumCheckCircle(isChecked: checked),
              SizedBox(width: _checkToLabel.w),
              Expanded(
                child: Text(
                  label,
                  style: (labelStyle ?? context.typo.input).copyWith(
                    color: colors.textPrimary,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
