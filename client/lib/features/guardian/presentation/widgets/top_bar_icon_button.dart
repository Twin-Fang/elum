import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../../core/theme/theme_context_ext.dart';
import '../../../../core/widgets/app_pressable.dart';

/// 상단바 오른쪽 그림 버튼 한 벌: 자리 24 안 그림 20 · 누름 영역 40 · 같은 색 (`?` · 임시저장, #1457)
/// 누름 영역은 자리 위로 덮음 (자리째 키우면 줄 높이가 바뀜)
class TopBarIconButton extends StatelessWidget {
  const TopBarIconButton({
    super.key,
    required this.iconAsset,
    required this.semanticLabel,
    required this.onTap,
  });

  final String iconAsset;
  final String semanticLabel;
  final VoidCallback? onTap;

  /// 자리 · 그림 · 누름 영역 한 변
  static const slotSize = 24.0;
  static const glyphSize = 20.0;
  static const touchSize = 40.0;

  @override
  Widget build(BuildContext context) => AppPressable(
    onTap: onTap,
    scaleDown: AppPressable.scaleIcon,
    semanticLabel: semanticLabel,
    child: SizedBox.square(
      dimension: slotSize.w,
      child: OverflowBox(
        maxWidth: touchSize.w,
        maxHeight: touchSize.w,
        child: SizedBox.square(
          dimension: touchSize.w,
          child: Center(
            child: SvgPicture.asset(
              iconAsset,
              width: glyphSize.w,
              height: glyphSize.w,
              colorFilter: ColorFilter.mode(context.colors.topBarActionText, BlendMode.srcIn),
            ),
          ),
        ),
      ),
    ),
  );
}
