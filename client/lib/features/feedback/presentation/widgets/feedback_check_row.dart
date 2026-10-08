import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../core/theme/theme_context_ext.dart';

/// 체크박스 한 줄. 줄 전체가 눌린다. 앱에 체크박스 컴포넌트가 없어 의견 화면용으로 둔다.
class FeedbackCheckRow extends StatelessWidget {
  const FeedbackCheckRow({
    super.key,
    required this.label,
    required this.checked,
    required this.onChanged,
  });

  final String label;
  final bool checked;

  /// null 이면 잠긴다(전송 중).
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final onTap = onChanged;
    final box = 24.w;

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
              Container(
                width: box,
                height: box,
                decoration: BoxDecoration(
                  color: checked ? colors.buttonEnabled : colors.surface,
                  borderRadius: BorderRadius.circular(6.r),
                  border: Border.all(
                    color: checked ? colors.buttonEnabled : colors.border,
                  ),
                ),
                child: checked
                    ? Icon(
                        Icons.check_rounded,
                        size: 18.w,
                        color: colors.buttonEnabledText,
                      )
                    : null,
              ),
              SizedBox(width: 12.w),
              Expanded(
                child: Text(
                  label,
                  style: context.typo.input.copyWith(
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
