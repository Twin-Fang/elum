import 'package:flutter/material.dart';

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
  });

  final String label;

  /// null이면 비활성 상태
  final VoidCallback? onPressed;

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
        height: space.buttonH,
        decoration: BoxDecoration(
          color: isEnabled ? colors.buttonEnabled : colors.buttonDisabled,
          borderRadius: BorderRadius.circular(space.buttonRadius),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: context.typo.button.copyWith(
            color: isEnabled
                ? colors.buttonEnabledText
                : colors.buttonDisabledText,
          ),
        ),
      ),
    );
  }
}
