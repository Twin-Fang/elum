import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../theme/theme_context_ext.dart';
import 'app_pressable.dart';
import 'elum_spinner.dart';

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
    this.labelStyle,
    this.loading = false,
  });

  final String label;

  /// null이면 비활성 상태
  final VoidCallback? onPressed;

  /// 배경색 재정의. 보상 화면처럼 어두운 배경 위에서는 기본색이 묻힌다.
  /// null이면 활성/비활성 토큰을 그대로 쓴다.
  final Color? backgroundColor;

  /// 문구색 재정의. [backgroundColor]와 짝으로 쓴다.
  final Color? labelColor;

  /// 문구 글자 재정의 (시트 안 버튼은 시안이 Pretendard 로 씀). null 이면 `button`.
  final TextStyle? labelStyle;

  /// 서버 응답을 기다리는 중. 누를 수 없고 오른쪽에 스피너가 돈다.
  ///
  /// 그대로 두면 보호자는 반응이 없는 줄 알고 다시 눌러 같은 요청이 두 번 간다.
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final space = context.space;
    final isEnabled = onPressed != null && !loading;

    // 눌림 반응은 AppPressable이 담당한다 (docs/motion.md).
    // ripple 대신 scale로 통일해 앱 전체 터치 피드백을 맞춘다.
    // 시안 높이는 최소값. 큰 글자로 문구가 줄바꿈되면 버튼이 늘어난다 (기본 크기에서는 66 그대로)
    // 낭독기: 버튼 역할 · 누를 수 있는지 (container 로 아래 탭 동작을 이 노드에 모은다)
    final button = Semantics(
      container: true,
      button: true,
      enabled: isEnabled,
      child: AppPressable(
        onTap: loading ? null : onPressed,
        child: Container(
          width: double.infinity,
          constraints: BoxConstraints(minHeight: space.buttonH.h),
          padding: EdgeInsets.symmetric(vertical: space.xs.h),
          decoration: BoxDecoration(
            color:
                backgroundColor ??
                (isEnabled ? colors.buttonEnabled : colors.buttonDisabled),
            borderRadius: BorderRadius.circular(space.buttonRadius.r),
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: (labelStyle ?? context.typo.button).copyWith(
              color:
                  labelColor ??
                  (isEnabled
                      ? colors.buttonEnabledText
                      : colors.buttonDisabledText),
            ),
          ),
        ),
      ),
    );
    if (!loading) return button;

    // 문구는 그대로 두고 오른쪽에 스피너만 얹는다 — 무엇을 하는 중인지 문구가 말해 준다.
    return Stack(
      alignment: Alignment.centerRight,
      children: [
        button,
        Padding(
          padding: EdgeInsets.only(right: 24.w),
          child: ElumSpinner(
            size: 22.w,
            color: labelColor ?? colors.buttonDisabledText,
          ),
        ),
      ],
    );
  }
}
