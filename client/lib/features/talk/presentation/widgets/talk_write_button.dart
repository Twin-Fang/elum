import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../../core/assets/app_assets.dart';
import '../../../../core/l10n/l10n_context.dart';
import '../../../../core/theme/theme_context_ext.dart';
import '../../../../core/widgets/app_pressable.dart';

/// 이야기 칸 아래 가운데 떠 있는 `+ 올리기` (시안 1783:6836)
/// 자리는 Scaffold 기본 centerFloat (하단 바 위 16)
class TalkWriteButton extends StatelessWidget {
  const TalkWriteButton({super.key, required this.onPressed});

  final VoidCallback onPressed;

  /// 버튼 높이 · 하단 바와의 간격 (시안 44 · 16)
  static const height = 44.0;
  static const navGap = 16.0;

  /// 목록 끝이 버튼 아래로 숨지 않게 남길 아래 여백 (버튼 + 간격 + 버튼 위 숨 16)
  static const scrollBottomSpace = height + navGap + 16;

  /// 더하기 한 변 · 아이콘과 글자 사이 · 좌우 여백 (시안: 폭 122 = 30 + 12 + 8 + 글자 + 30)
  static const _iconSize = 12.0;
  static const _iconToLabel = 8.0;
  static const _horizontalPadding = 30.0;

  /// 그림자 (#242634 25%, 아래 4, 흐림 20)
  static const _shadowAlpha = 0.25;
  static const _shadowBlur = 20.0;
  static const _shadowOffsetY = 4.0;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final scaledHeight = height.h;
    return AppPressable(
      onTap: onPressed,
      child: Container(
        height: scaledHeight,
        padding: EdgeInsets.symmetric(horizontal: _horizontalPadding.w),
        decoration: BoxDecoration(
          color: colors.buttonEnabled,
          borderRadius: BorderRadius.circular(scaledHeight / 2),
          boxShadow: [
            BoxShadow(
              color: colors.buttonEnabled.withValues(alpha: _shadowAlpha),
              blurRadius: _shadowBlur,
              offset: Offset(0, _shadowOffsetY.h),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SvgPicture.asset(
              AppAssets.iconPlus,
              width: _iconSize.w,
              height: _iconSize.w,
              colorFilter: ColorFilter.mode(
                colors.buttonEnabledText,
                BlendMode.srcIn,
              ),
            ),
            SizedBox(width: _iconToLabel.w),
            Text(
              context.l10n.talkWriteButton,
              style: context.typo.talkWriteLabel.copyWith(
                color: colors.buttonEnabledText,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
