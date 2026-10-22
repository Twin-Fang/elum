import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../theme/theme_context_ext.dart';
import 'app_pressable.dart';

/// 밑줄 친 회색 글자 버튼 (시안 1082:4709 `나중에 할게요` · 204:991 `초대 코드가 있어요`): Pretendard 600/16
/// 보조 동작 (나중에 · 건너뛰기 · 끄기) 에 쓴다. Material `TextButton` 을 대신한다
class ElumTextLink extends StatelessWidget {
  const ElumTextLink({
    super.key,
    required this.label,
    required this.onTap,
    this.textAlign = TextAlign.center,
  });

  final String label;
  final VoidCallback? onTap;
  final TextAlign textAlign;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return AppPressable(
      onTap: onTap,
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: context.space.xs.w,
          vertical: context.space.xs.h,
        ),
        child: Text(
          label,
          textAlign: textAlign,
          style: context.typo.linkLater.copyWith(
            color: colors.linkLaterLabel,
            decoration: TextDecoration.underline,
            decorationColor: colors.linkLaterLabel,
          ),
        ),
      ),
    );
  }
}
