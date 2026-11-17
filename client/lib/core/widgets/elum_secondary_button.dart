import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../haptics/tap_haptics.dart';
import '../theme/theme_context_ext.dart';
import 'app_pressable.dart';

/// 보조 버튼: 연한 회색 판 + 진한 글자 (나중에 · 건너뛰기 · 끄기 · 닫기 · 다시 시도)
/// 주 버튼(ElumButton) 아래는 폭 가득, 글 줄 사이에 끼면 [isCompact] 로 글자 폭만 (#1401)
class ElumSecondaryButton extends StatelessWidget {
  const ElumSecondaryButton({
    super.key,
    required this.label,
    required this.onTap,
    this.isCompact = false,
    this.leading,
  });

  final String label;

  /// null 이면 꺼진 버튼 (글자만 흐리게, 눌림 반응 없음)
  final VoidCallback? onTap;

  /// true: 글자 폭 + 옆 여백 (빈 화면 · 오류 줄 · 암호 아래처럼 흐르는 내용 안)
  final bool isCompact;

  /// 글자 앞 작은 그림 (예시 일과 열기의 겹친 카드)
  final Widget? leading;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final space = context.space;
    final isEnabled = onTap != null;
    final leading = this.leading;
    final labelText = Text(
      label,
      textAlign: TextAlign.center,
      style: context.typo.linkLater.copyWith(
        color: isEnabled ? colors.buttonNeutralText : colors.linkLaterLabel,
      ),
    );

    // 높이 48 = xl + md (주 버튼 66 보다 낮게 · 큰 글자면 늘어남)
    // 낭독기: 버튼 역할 · 누를 수 있는지 (ElumButton 과 같음)
    return Semantics(
      container: true,
      button: true,
      enabled: isEnabled,
      child: AppPressable(
        onTap: withTapHaptic(onTap),
        child: Container(
          width: isCompact ? null : double.infinity,
          constraints: BoxConstraints(minHeight: (space.xl + space.md).h),
          padding: EdgeInsets.symmetric(horizontal: space.lg.w, vertical: space.xs.h),
          decoration: BoxDecoration(
            color: colors.buttonNeutral,
            borderRadius: BorderRadius.circular(space.buttonRadius.r),
          ),
          alignment: isCompact ? null : Alignment.center,
          child: leading == null
              ? (isCompact ? Center(widthFactor: 1, heightFactor: 1, child: labelText) : labelText)
              : Row(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    leading,
                    SizedBox(width: space.xs.w),
                    Flexible(child: labelText),
                  ],
                ),
        ),
      ),
    );
  }
}
