import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../theme/theme_context_ext.dart';
import 'app_pressable.dart';

/// 하단 CTA 버튼. Figma 컴포넌트셋 `일반 버튼`(187:299)에 대응한다.
///
/// 360×66 / radius 18 / 텍스트 22·w800.
/// `onPressed`가 null이면 disable variant로 렌더링된다.
class ElumButton extends StatelessWidget {
  const ElumButton({
    super.key,
    required this.label,
    this.onPressed,
    this.backgroundColor,
    this.labelColor,
  });

  final String label;

  /// null이면 비활성 상태
  final VoidCallback? onPressed;

  /// 배경색 재정의. 보상 화면처럼 어두운 배경 위에서는 기본색이 묻힌다.
  /// null이면 활성/비활성 토큰을 그대로 쓴다.
  final Color? backgroundColor;

  /// 문구색 재정의. [backgroundColor]와 짝으로 쓴다.
  final Color? labelColor;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final space = context.space;
    final isEnabled = onPressed != null;

    // 눌림 반응은 AppPressable이 담당한다 (docs/motion.md).
    // ripple 대신 scale로 통일해 앱 전체 터치 피드백을 맞춘다.
    return AppPressable(
      onTap: onPressed,
      child: Container(
        width: double.infinity,
        height: space.buttonH.h,
        decoration: BoxDecoration(
          color: backgroundColor ??
              (isEnabled ? colors.buttonEnabled : colors.buttonDisabled),
          borderRadius: BorderRadius.circular(space.buttonRadius.r),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: context.typo.button.copyWith(
            color: labelColor ??
                (isEnabled
                    ? colors.buttonEnabledText
                    : colors.buttonDisabledText),
          ),
        ),
      ),
    );
  }
}
